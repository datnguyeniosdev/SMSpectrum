import Foundation
import SMSpectrumRenderer

/// Orientation of the band axis for line-based styles
/// (`.digital`, `.analogLines`, `.analogDots`, `.lineGradient`, `.waveform`).
///
/// `.horizontal` (default): bands run left → right; bars extend up/down per
/// `SMSide`. `.vertical`: bands run top → bottom; bars extend right/left per
/// `SMSide`. Circle-based styles ignore this option.
///
/// Side mapping per orientation:
/// - **Horizontal** — `sideA` = top, `sideB` = bottom, `both` = mirrored vertical
/// - **Vertical** — `sideA` = right, `sideB` = left, `both` = mirrored horizontal
public enum SMOrientation: Equatable {
    case horizontal
    case vertical
}

extension SMOrientation {
    var renderOrientation: RenderOrientation {
        switch self {
        case .horizontal: return .horizontal
        case .vertical: return .vertical
        }
    }
}
