import Foundation
import CoreGraphics

/// Samples points uniformly by arc-length along an arbitrary `CGPath`.
///
/// Used by the renderer when `SMPath.custom` is selected, so each band lands
/// on an evenly spaced position regardless of bezier control density.
struct PathSampler {

    /// Returns `count` points along `path`, in path coordinate space.
    static func sample(_ path: CGPath, count: Int) -> [CGPoint] {
        precondition(count > 0)
        let flattened = path.copy(dashingWithPhase: 0, lengths: []) // forces flattening
        let segments = collectSegments(from: flattened)
        guard !segments.isEmpty else { return [] }

        let totalLength = segments.reduce(0) { $0 + $1.length }
        guard totalLength > 0 else { return Array(repeating: .zero, count: count) }

        var output: [CGPoint] = []
        output.reserveCapacity(count)
        let stepLength = totalLength / CGFloat(count - 1).clampedAboveZero

        var traversed: CGFloat = 0
        var segmentIndex = 0
        for i in 0..<count {
            let target = stepLength * CGFloat(i)
            while segmentIndex < segments.count - 1 && traversed + segments[segmentIndex].length < target {
                traversed += segments[segmentIndex].length
                segmentIndex += 1
            }
            let segment = segments[segmentIndex]
            let localT = segment.length > 0 ? (target - traversed) / segment.length : 0
            let point = CGPoint(
                x: segment.start.x + (segment.end.x - segment.start.x) * localT,
                y: segment.start.y + (segment.end.y - segment.start.y) * localT
            )
            output.append(point)
        }
        return output
    }

    private struct Segment {
        let start: CGPoint
        let end: CGPoint
        var length: CGFloat {
            hypot(end.x - start.x, end.y - start.y)
        }
    }

    private static func collectSegments(from path: CGPath) -> [Segment] {
        var segments: [Segment] = []
        var current: CGPoint = .zero
        var subpathStart: CGPoint = .zero

        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            let points = element.points
            switch element.type {
            case .moveToPoint:
                current = points[0]
                subpathStart = current
            case .addLineToPoint:
                segments.append(Segment(start: current, end: points[0]))
                current = points[0]
            case .addQuadCurveToPoint, .addCurveToPoint:
                // Should not occur after dashingWithPhase flattening, but guard anyway.
                let last = element.type == .addCurveToPoint ? points[2] : points[1]
                segments.append(Segment(start: current, end: last))
                current = last
            case .closeSubpath:
                segments.append(Segment(start: current, end: subpathStart))
                current = subpathStart
            @unknown default:
                break
            }
        }
        return segments
    }
}

private extension CGFloat {
    var clampedAboveZero: CGFloat { self > 0 ? self : 1 }
}
