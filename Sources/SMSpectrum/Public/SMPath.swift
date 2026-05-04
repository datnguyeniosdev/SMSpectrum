import Foundation
import CoreGraphics
import SMSpectrumRenderer

/// Geometric layout for band placement.
public enum SMPath: Equatable {
    case line(from: CGPoint, to: CGPoint)
    case circle(center: CGPoint, radius: CGFloat)
    case custom(CGPath)

    public static func == (lhs: SMPath, rhs: SMPath) -> Bool {
        switch (lhs, rhs) {
        case (.line(let a1, let b1), .line(let a2, let b2)):
            return a1 == a2 && b1 == b2
        case (.circle(let c1, let r1), .circle(let c2, let r2)):
            return c1 == c2 && r1 == r2
        case (.custom(let p1), .custom(let p2)):
            return p1 == p2
        default:
            return false
        }
    }
}

extension SMPath {
    var renderPath: RenderPath {
        switch self {
        case .line(let from, let to): return .line(from: from, to: to)
        case .circle(let center, let radius): return .circle(center: center, radius: radius)
        case .custom(let path): return .custom(path)
        }
    }
}
