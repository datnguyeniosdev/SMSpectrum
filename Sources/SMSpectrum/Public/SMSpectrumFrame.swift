import Foundation
import QuartzCore

/// Per-frame analysis output exposed to delegates and observers, and the
/// canonical input shape for `SMSpectrumView.push(frame:)` when feeding the
/// view custom (non-audio-engine) data.
public struct SMSpectrumFrame {
    /// Normalized 0...1 magnitudes per band. Length should equal
    /// `SMConfiguration.bandCount` for unambiguous rendering — if it differs
    /// the view falls back to log-band remapping.
    public let magnitudes: [Float]

    /// Frame timestamp in seconds. Defaults to wall clock when omitted.
    public let timestamp: TimeInterval

    /// Center frequency of each band in Hz. Pass an empty array if you don't
    /// have this information; the view will compute it from the configuration
    /// before forwarding to delegates.
    public let bandFrequencies: [Float]

    public init(
        magnitudes: [Float],
        timestamp: TimeInterval = CACurrentMediaTime(),
        bandFrequencies: [Float] = []
    ) {
        self.magnitudes = magnitudes
        self.timestamp = timestamp
        self.bandFrequencies = bandFrequencies
    }
}
