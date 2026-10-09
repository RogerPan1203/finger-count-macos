import AVFoundation
import Combine
import CoreGraphics
import Foundation
import ImageIO
import Vision

struct HandReading: Identifiable {
    let id: Int
    let count: Int
    let fingerStates: [Bool]
}

final class CameraModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var statusText = AppLanguage.saved.text("等待开启摄像头", "Ready to start camera")
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRunning = false
    @Published private(set) var isStarting = false
    @Published private(set) var total: Int?
    @Published private(set) var hands: [HandReading] = []
    @Published private(set) var handPoints: [[CGPoint]] = []
    @Published private(set) var frameSize = CGSize(width: 1280, height: 720)
    @Published private(set) var framesPerSecond = 0
    @Published private(set) var isMirrored = true

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "FingerCount.camera.session")
    private let processingQueue = DispatchQueue(label: "FingerCount.camera.vision", qos: .userInitiated)
    private let handRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }()
    private var isConfigured = false
    // Accessed only on the main thread; stale permission/configuration callbacks
    // must not restart a camera the user has already stopped.
    private var startGeneration = 0
    private var lastFrameTime: CFAbsoluteTime = 0
    private var lastFPSUpdate: CFAbsoluteTime = 0
    private var processedFrames = 0
    private var recentTotals: [Int] = []
    private var lastStableTotal: Int?
    private var language = AppLanguage.saved
    private var statusMessages = (chinese: "等待开启摄像头", english: "Ready to start camera")
    private var errorMessages: (chinese: String, english: String)?

    private var sessionObservers: [NSObjectProtocol] = []

    override init() {
        super.init()
        let center = NotificationCenter.default
        sessionObservers = [
            center.addObserver(forName: .AVCaptureSessionWasInterrupted, object: session, queue: .main) { [weak self] _ in
                self?.handleSessionFailure("摄像头被系统或其他应用暂时占用。请稍后重试。",
                                           "The camera is temporarily in use by the system or another app. Please try again.")
            },
            center.addObserver(forName: .AVCaptureSessionRuntimeError, object: session, queue: .main) { [weak self] _ in
                self?.handleSessionFailure("摄像头运行中断。请检查连接并重试。",
                                           "The camera stopped unexpectedly. Check its connection and try again.")
            }
        ]
    }

    deinit {
        for observer in sessionObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        statusText = language.text(statusMessages.chinese, statusMessages.english)
        if let messages = errorMessages {
            errorMessage = language.text(messages.chinese, messages.english)
        }
    }

    private func setStatus(_ chinese: String, _ english: String) {
        statusMessages = (chinese, english)
        statusText = language.text(chinese, english)
    }

    private func setError(_ chinese: String, _ english: String) {
        errorMessages = (chinese, english)
        errorMessage = language.text(chinese, english)
    }

    private func clearError() {
        errorMessages = nil
        errorMessage = nil
    }

    func start() {
        guard !isStarting && !isRunning else { return }
        startGeneration += 1
        let generation = startGeneration
        clearError()
        isStarting = true
        setStatus("正在请求摄像头权限…", "Requesting camera access…")

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart(generation: generation)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.startGeneration == generation, self.isStarting else { return }
                    if granted {
                        self.configureAndStart(generation: generation)
                    } else {
                        self.fail("未获得摄像头权限。请在系统设置 → 隐私与安全性 → 摄像头中允许此应用访问。",
                                  "Camera access was not granted. Allow this app in System Settings → Privacy & Security → Camera.")
                    }
                }
            }
        case .denied, .restricted:
            fail("摄像头访问被关闭。请在系统设置 → 隐私与安全性 → 摄像头中允许此应用访问。",
                 "Camera access is disabled. Allow this app in System Settings → Privacy & Security → Camera.")
        @unknown default:
            fail("无法确认摄像头权限，请重试。", "Could not confirm camera access. Please try again.")
        }
    }

    func stop() {
        guard isRunning || isStarting else { return }
        startGeneration += 1
        isRunning = false
        isStarting = false
        setStatus("摄像头已关闭", "Camera off")
        clearError()
        total = nil
        hands = []
        handPoints = []
        framesPerSecond = 0
        processingQueue.async { [weak self] in
            self?.recentTotals.removeAll()
            self?.lastStableTotal = nil
            self?.lastFrameTime = 0
            self?.lastFPSUpdate = 0
            self?.processedFrames = 0
        }
        let session = self.session
        sessionQueue.async {
            session.stopRunning()
        }
    }

    func toggleMirror() {
        isMirrored.toggle()
    }

    private func configureAndStart(generation: Int) {
        setStatus("正在连接摄像头…", "Connecting to camera…")
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                guard let camera = AVCaptureDevice.default(for: .video) else {
                    DispatchQueue.main.async {
                        if self.startGeneration == generation {
                            self.fail("未检测到摄像头。请连接摄像头后重试。",
                                      "No camera found. Connect a camera and try again.")
                        }
                    }
                    return
                }
                do {
                    let input = try AVCaptureDeviceInput(device: camera)
                    let output = AVCaptureVideoDataOutput()
                    output.alwaysDiscardsLateVideoFrames = true
                    output.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    output.setSampleBufferDelegate(self, queue: self.processingQueue)

                    self.session.beginConfiguration()
                    self.session.sessionPreset = .high
                    guard self.session.canAddInput(input), self.session.canAddOutput(output) else {
                        self.session.commitConfiguration()
                        DispatchQueue.main.async {
                            if self.startGeneration == generation {
                                self.fail("无法配置摄像头，请关闭其他占用摄像头的应用后重试。",
                                          "Could not configure the camera. Close other apps using it and try again.")
                            }
                        }
                        return
                    }
                    self.session.addInput(input)
                    self.session.addOutput(output)
                    self.session.commitConfiguration()
                    self.isConfigured = true
                } catch {
                    DispatchQueue.main.async {
                        if self.startGeneration == generation {
                            self.fail("摄像头连接失败：\(error.localizedDescription)",
                                      "Camera connection failed: \(error.localizedDescription)")
                        }
                    }
                    return
                }
            }

            self.session.startRunning()
            DispatchQueue.main.async {
                guard self.startGeneration == generation else { return }
                if self.session.isRunning {
                    self.isStarting = false
                    self.isRunning = true
                    self.setStatus("正在识别手指", "Counting fingers")
                } else {
                    self.fail("摄像头没有启动，请重试。", "The camera did not start. Please try again.")
                }
            }
        }
    }

    private func fail(_ chinese: String, _ english: String) {
        isStarting = false
        isRunning = false
        setError(chinese, english)
        setStatus("无法使用摄像头", "Camera unavailable")
    }

    private func handleSessionFailure(_ chinese: String, _ english: String) {
        guard isRunning || isStarting else { return }
        stop()
        fail(chinese, english)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFrameTime >= 1.0 / 24.0 else { return }
        lastFrameTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([handRequest])
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isRunning else { return }
                self.setError("手部识别暂时失败：\(error.localizedDescription)",
                              "Hand tracking temporarily failed: \(error.localizedDescription)")
            }
            return
        }

        let readings: [(points: [CGPoint], result: FingerCountResult)] =
            (handRequest.results ?? []).compactMap { observation in
                guard let points = Self.landmarks(from: observation),
                      let result = FingerCounter.count(points) else { return nil }
                return (points, result)
            }

        let rawTotal = readings.reduce(0) { $0 + $1.result.count }
        let smoothedTotal: Int?
        if readings.isEmpty {
            recentTotals.removeAll()
            lastStableTotal = nil
            smoothedTotal = nil
        } else {
            recentTotals.append(rawTotal)
            if recentTotals.count > 5 { recentTotals.removeFirst() }
            let counts = Dictionary(recentTotals.map { ($0, 1) }, uniquingKeysWith: +)
            let mostVotes = counts.values.max() ?? 0
            let candidates = counts.filter { $0.value == mostVotes }.map(\.key)
            if let previous = lastStableTotal, candidates.contains(previous) {
                smoothedTotal = previous
            } else if candidates.contains(rawTotal) {
                smoothedTotal = rawTotal
            } else {
                smoothedTotal = candidates.min()
            }
            lastStableTotal = smoothedTotal
        }

        if lastFPSUpdate == 0 { lastFPSUpdate = now }
        processedFrames += 1
        var fps: Int?
        if now - lastFPSUpdate >= 1 {
            fps = Int((Double(processedFrames) / max(now - lastFPSUpdate, 0.001)).rounded())
            processedFrames = 0
            lastFPSUpdate = now
        }

        let handValues = readings.enumerated().map { index, item in
            HandReading(id: index, count: item.result.count, fingerStates: item.result.states)
        }
        let allPoints = readings.map(\.points)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRunning else { return }
            self.clearError()
            self.hands = handValues
            self.handPoints = allPoints
            self.total = smoothedTotal
            if self.frameSize != size { self.frameSize = size }
            if let fps { self.framesPerSecond = fps }
        }
    }

    private static func landmarks(from observation: VNHumanHandPoseObservation) -> [CGPoint]? {
        let order: [VNHumanHandPoseObservation.JointName] = [
            .wrist,
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip
        ]
        guard let detected = try? observation.recognizedPoints(.all) else { return nil }
        var points: [CGPoint] = []
        let palmJoints: Set<Int> = [0, 5, 9, 13, 17]
        for (index, joint) in order.enumerated() {
            if let point = detected[joint], point.confidence >= 0.15 {
                points.append(point.location)
            } else if palmJoints.contains(index) {
                // A missing palm anchor makes the hand geometry unreliable.
                return nil
            } else {
                // Closed or occluded fingertips often have low confidence.
                // Collapse them toward the previous joint, which classifies
                // that finger as folded without discarding the entire hand.
                points.append(points[index - 1])
            }
        }
        return points
    }
}
