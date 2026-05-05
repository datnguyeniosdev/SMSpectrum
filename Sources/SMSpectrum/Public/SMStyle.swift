import Foundation
import SMSpectrumRenderer

/// Public-facing visual style. Mirrors `RenderStyle` but lives in the
/// `SMSpectrum` umbrella so consumers don't need to import the renderer.
public enum SMStyle: Equatable {
    case digital
    case analogLines
    case analogDots
    case circle
    case lineGradient

    /// Circular stroke tracing magnitudes around a ring — outer edge only,
    /// no fill. Uses the circle-line pipeline with smooth Catmull-Rom
    /// interpolation along the arc.
    case circleLine

    /// Single-sided thin polyline above the baseline. Visually similar to a
    /// time-domain waveform — flat at silence with sharp peaks for transients.
    /// Internally reuses the analog-line pipeline with snappy smoothing.
    case waveform
}

extension SMStyle {
    /// Returns the renderer-side style. `circle` resolves to `.circleBars` by
    /// default — the configuration's `circleMode` upgrades it to
    /// `.circleHermite` when needed.
    func renderStyle(circleMode: SMCircleMode = .bars) -> RenderStyle {
        switch self {
        case .digital: return .digitalBars
        case .analogLines: return .analogLines
        case .analogDots: return .analogDots
        case .circle:
            switch circleMode {
            case .bars: return .circleBars
            case .cubicHermite: return .circleHermite
            }
        case .lineGradient: return .lineGradient
        case .circleLine: return .circleLine
        case .waveform: return .analogLines
        }
    }
}
