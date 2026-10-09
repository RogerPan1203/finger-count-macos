import CoreGraphics
import Foundation

/// Finger order in `states`: thumb, index, middle, ring, pinky.
struct FingerCountResult {
    let count: Int
    let states: [Bool]

    /// Distance from the gesture decision boundaries, from 0 to 1.
    /// This is a heuristic certainty score, not a calibrated probability.
    let confidence: Double
}

/// Counts visibly extended fingers in a single hand's 21 landmarks.
///
/// The landmark order is wrist (0), thumb CMC/MCP/IP/tip (1...4), then
/// MCP/PIP/DIP/tip for index, middle, ring, and pinky (5...20). Only relative
/// 2D geometry is used, so in-plane rotation, scale, and mirroring do not
/// change the classification. Heavy occlusion and an edge-on palm can still
/// make 2D finger poses ambiguous.
enum FingerCounter {
    static func count(_ landmarks: [CGPoint]) -> FingerCountResult? {
        guard landmarks.count >= 21,
              landmarks.prefix(21).allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              distance(landmarks[5], landmarks[17]) > epsilon else {
            return nil
        }

        let decisions = [
            thumb(landmarks),
            longFinger(landmarks, mcp: 5, pip: 6, dip: 7, tip: 8),
            longFinger(landmarks, mcp: 9, pip: 10, dip: 11, tip: 12),
            longFinger(landmarks, mcp: 13, pip: 14, dip: 15, tip: 16),
            longFinger(landmarks, mcp: 17, pip: 18, dip: 19, tip: 20)
        ]
        let states = decisions.map(\.extended)
        return FingerCountResult(
            count: states.filter { $0 }.count,
            states: states,
            confidence: decisions.map(\.confidence).reduce(0, +) / Double(decisions.count)
        )
    }

    private static let epsilon = 1e-8

    private struct Vector {
        let x: Double
        let y: Double

        init(from: CGPoint, to: CGPoint) {
            x = Double(to.x - from.x)
            y = Double(to.y - from.y)
        }

        var length: Double { hypot(x, y) }

        func dot(_ other: Vector) -> Double { x * other.x + y * other.y }
    }

    private struct Decision {
        let extended: Bool
        let confidence: Double
    }

    private static func clamp(_ value: Double, lower: Double = 0, upper: Double = 1) -> Double {
        min(upper, max(lower, value))
    }

    private static func ramp(_ value: Double, from low: Double, to high: Double) -> Double {
        clamp((value - low) / (high - low))
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        Vector(from: a, to: b).length
    }

    private static func jointAngle(_ a: CGPoint, _ joint: CGPoint, _ b: CGPoint) -> Double? {
        let left = Vector(from: joint, to: a)
        let right = Vector(from: joint, to: b)
        let denominator = left.length * right.length
        guard denominator > epsilon else { return nil }
        return acos(clamp(left.dot(right) / denominator, lower: -1, upper: 1)) * 180 / .pi
    }

    private static func decision(_ score: Double, threshold: Double, reliable: Bool = true) -> Decision {
        let extended = score >= threshold
        let range = extended ? 1 - threshold : threshold
        let confidence = reliable ? clamp(abs(score - threshold) / range) : 0
        return Decision(extended: extended, confidence: confidence)
    }

    private static func longFinger(
        _ points: [CGPoint], mcp: Int, pip: Int, dip: Int, tip: Int
    ) -> Decision {
        let base = points[mcp]
        let first = points[pip]
        let second = points[dip]
        let end = points[tip]
        let wrist = points[0]
        let length = distance(base, first) + distance(first, second) + distance(second, end)
        let palmRay = Vector(from: wrist, to: base)
        let fingerRay = Vector(from: base, to: end)
        guard length > epsilon, palmRay.length > epsilon,
              let pipAngle = jointAngle(base, first, second),
              let dipAngle = jointAngle(first, second, end) else {
            return decision(0, threshold: 0.52, reliable: false)
        }

        // Curling shortens the MCP-to-tip reach and bends the PIP/DIP joints.
        // Wrist-relative progress also catches fingers folded back over the palm.
        let reach = distance(base, end) / length
        let progress = (distance(wrist, end) - distance(wrist, base)) / length
        var score = 0.39 * ramp(reach, from: 0.68, to: 0.92)
            + 0.21 * ramp(pipAngle, from: 120, to: 165)
            + 0.10 * ramp(dipAngle, from: 115, to: 160)
            + 0.30 * ramp(progress, from: 0.04, to: 0.39)

        // A straight finger pointing into the palm is flexed at its MCP joint.
        let alignment = fingerRay.dot(palmRay) / (fingerRay.length * palmRay.length + epsilon)
        if alignment < -0.12 {
            score *= ramp(alignment, from: -0.45, to: -0.12)
        }
        return decision(score, threshold: 0.52)
    }

    private static func thumb(_ points: [CGPoint]) -> Decision {
        let mcp = points[2]
        let ip = points[3]
        let tip = points[4]
        let indexMcp = points[5]
        let pinkyMcp = points[17]
        let palmWidth = distance(indexMcp, pinkyMcp)
        let thumbLength = distance(mcp, ip) + distance(ip, tip)
        guard palmWidth > epsilon, thumbLength > epsilon,
              jointAngle(mcp, ip, tip) != nil else {
            return decision(0, threshold: 0.51, reliable: false)
        }

        // The anatomical pinky-to-index axis works for either hand and for a
        // mirrored preview. A tucked thumb stays close to the palm/MCPs.
        let acrossPalm = Vector(from: pinkyMcp, to: indexMcp)
        let lateral = Vector(from: indexMcp, to: tip).dot(acrossPalm) / (palmWidth * palmWidth)
        let pinkySeparation = distance(tip, pinkyMcp) / palmWidth
        let indexSeparation = distance(tip, indexMcp) / palmWidth
        let reach = distance(mcp, tip) / thumbLength
        let score = 0.37 * ramp(lateral, from: 0.12, to: 0.62)
            + 0.25 * ramp(pinkySeparation, from: 1.08, to: 1.62)
            + 0.25 * ramp(indexSeparation, from: 0.34, to: 0.78)
            + 0.13 * ramp(reach, from: 0.66, to: 0.91)
        return decision(score, threshold: 0.51)
    }
}
