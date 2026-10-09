import CoreGraphics
import Foundation

@main
struct FingerCounterTests {
    private static let open: [[CGPoint]] = [
        [p(0.36, 0.76), p(0.28, 0.69), p(0.19, 0.57), p(0.11, 0.53)],
        [p(0.38, 0.53), p(0.34, 0.39), p(0.33, 0.29), p(0.32, 0.20)],
        [p(0.49, 0.51), p(0.49, 0.33), p(0.49, 0.23), p(0.49, 0.13)],
        [p(0.61, 0.53), p(0.63, 0.38), p(0.65, 0.29), p(0.66, 0.20)],
        [p(0.73, 0.58), p(0.77, 0.45), p(0.80, 0.36), p(0.82, 0.29)]
    ]

    private static let closed: [[CGPoint]] = [
        [p(0.36, 0.76), p(0.28, 0.69), p(0.41, 0.67), p(0.48, 0.62)],
        [p(0.38, 0.53), p(0.37, 0.47), p(0.44, 0.50), p(0.44, 0.56)],
        [p(0.49, 0.51), p(0.50, 0.45), p(0.55, 0.48), p(0.54, 0.54)],
        [p(0.61, 0.53), p(0.62, 0.48), p(0.67, 0.51), p(0.66, 0.56)],
        [p(0.73, 0.58), p(0.75, 0.53), p(0.80, 0.56), p(0.78, 0.61)]
    ]

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y)
    }

    private static func hand(openFingers: Set<Int>) -> [CGPoint] {
        var landmarks = Array(repeating: CGPoint.zero, count: 21)
        landmarks[0] = p(0.50, 0.95)
        for finger in 0..<5 {
            let joints = openFingers.contains(finger) ? open[finger] : closed[finger]
            let first = finger == 0 ? 1 : 5 + (finger - 1) * 4
            for joint in 0..<4 { landmarks[first + joint] = joints[joint] }
        }
        return landmarks
    }

    private static func transformed(
        _ points: [CGPoint], radians: Double, mirrored: Bool, scale: Double
    ) -> [CGPoint] {
        let cosine = cos(radians)
        let sine = sin(radians)
        return points.map { point in
            let x = (mirrored ? 1 - Double(point.x) : Double(point.x)) - 0.5
            let y = Double(point.y) - 0.5
            return p(
                CGFloat(0.5 + scale * (x * cosine - y * sine)),
                CGFloat(0.5 + scale * (x * sine + y * cosine))
            )
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fatalError(message) }
    }

    static func main() {
        // All 32 combinations are checked, including isolated fingers and a fist.
        for mask in 0..<32 {
            let openFingers = Set((0..<5).filter { mask & (1 << $0) != 0 })
            let result = FingerCounter.count(hand(openFingers: openFingers))
            expect(result != nil, "The pose should have valid landmarks")
            expect(result?.count == openFingers.count,
                   "Expected \(openFingers.count) fingers; got \(String(describing: result?.count))")
            expect(result?.states == (0..<5).map { openFingers.contains($0) },
                   "Wrong per-finger states for mask \(mask)")
            expect((0...1).contains(result!.confidence), "Confidence must be in [0, 1]")
        }

        let three = hand(openFingers: [0, 1, 4])
        for mirrored in [false, true] {
            for radians in [0.0, Double.pi / 3, Double.pi, -Double.pi / 2] {
                let result = FingerCounter.count(transformed(three, radians: radians, mirrored: mirrored, scale: 0.43))
                expect(result?.states == [true, true, false, false, true],
                       "Rotation or mirror changed the finger states")
            }
        }

        expect(FingerCounter.count([]) == nil, "An incomplete landmark set should be rejected")
        expect(FingerCounter.count(Array(repeating: .zero, count: 21)) == nil,
               "A degenerate palm should be rejected")
        var nonFinite = hand(openFingers: [1])
        nonFinite[8].x = .nan
        expect(FingerCounter.count(nonFinite) == nil, "Non-finite landmarks should be rejected")
        print("FingerCounterTests passed")
    }
}
