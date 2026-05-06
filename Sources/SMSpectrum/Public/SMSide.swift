import Foundation
import SMSpectrumRenderer

/// Side mirroring options.
public enum SMSide: Equatable {
    case sideA
    case sideB
    case both
}

extension SMSide {
    var renderSideMode: RenderSideMode {
        switch self {
        case .sideA: return .sideA
        case .sideB: return .sideB
        case .both: return .both
        }
    }
}
