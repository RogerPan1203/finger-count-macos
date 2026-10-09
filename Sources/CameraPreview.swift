import AppKit
import AVFoundation
import SwiftUI

/// A live camera preview with the hand landmarks drawn in the same aspect-fill
/// coordinate space. `handPoints` uses Vision's normalized bottom-left origin
/// and the standard 21-point hand order.
struct CameraPreview: View {
    let session: AVCaptureSession
    let handPoints: [[CGPoint]]
    let frameSize: CGSize
    let mirrored: Bool

    private static let connections: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 4),
        (0, 5), (5, 6), (6, 7), (7, 8),
        (5, 9), (9, 10), (10, 11), (11, 12),
        (9, 13), (13, 14), (14, 15), (15, 16),
        (13, 17), (17, 18), (18, 19), (19, 20),
        (0, 17)
    ]

    var body: some View {
        CameraSurface(session: session, mirrored: mirrored)
            .overlay {
                Canvas { context, size in
                    drawHands(in: context, size: size)
                }
                .allowsHitTesting(false)
            }
            .background(Color.black)
            .clipped()
    }

    private func drawHands(in context: GraphicsContext, size: CGSize) {
        guard frameSize.width > 0, frameSize.height > 0,
              frameSize.width.isFinite, frameSize.height.isFinite,
              size.width > 0, size.height > 0 else { return }

        // AVCaptureVideoPreviewLayer uses resizeAspectFill, so the video can
        // extend past the view's edges. Apply that same scale and center crop.
        let scale = max(size.width / frameSize.width, size.height / frameSize.height)
        let videoWidth = frameSize.width * scale
        let videoHeight = frameSize.height * scale
        let offsetX = (size.width - videoWidth) / 2
        let offsetY = (size.height - videoHeight) / 2
        let colors = [
            Color(red: 0.35, green: 0.98, blue: 0.75),
            Color(red: 1.00, green: 0.78, blue: 0.38)
        ]

        for (handIndex, hand) in handPoints.enumerated() where hand.count >= 21 {
            let color = colors[handIndex % colors.count]
            let points: [CGPoint?] = hand.prefix(21).map { point in
                guard point.x.isFinite, point.y.isFinite else { return nil }
                return CGPoint(
                    x: offsetX + (mirrored ? 1 - point.x : point.x) * videoWidth,
                    y: offsetY + (1 - point.y) * videoHeight
                )
            }

            var skeleton = Path()
            for (start, end) in Self.connections {
                guard let first = points[start], let second = points[end] else { continue }
                skeleton.move(to: first)
                skeleton.addLine(to: second)
            }
            context.stroke(skeleton, with: .color(.black.opacity(0.65)), lineWidth: 5)
            context.stroke(skeleton, with: .color(color), lineWidth: 2.5)

            var halos = Path()
            var dots = Path()
            for point in points.compactMap({ $0 }) {
                halos.addEllipse(in: CGRect(x: point.x - 4.5, y: point.y - 4.5,
                                            width: 9, height: 9))
                dots.addEllipse(in: CGRect(x: point.x - 2.7, y: point.y - 2.7,
                                           width: 5.4, height: 5.4))
            }
            context.fill(halos, with: .color(.black.opacity(0.75)))
            context.fill(dots, with: .color(color))
        }
    }
}

private struct CameraSurface: NSViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.configure(session: session, mirrored: mirrored)
        return view
    }

    func updateNSView(_ view: CameraPreviewNSView, context: Context) {
        view.configure(session: session, mirrored: mirrored)
    }
}

final class CameraPreviewNSView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private var mirrorPreview = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    convenience init() {
        self.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(session: AVCaptureSession, mirrored: Bool) {
        if previewLayer.session !== session {
            previewLayer.session = session
        }
        mirrorPreview = mirrored
        applyMirroring()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        applyMirroring()
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyMirroring()
    }

    private func applyMirroring() {
        guard let connection = previewLayer.connection,
              connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirrorPreview
    }
}
