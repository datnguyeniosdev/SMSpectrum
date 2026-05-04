import Foundation

/// Per-frame analysis output exposed to delegates and observers.
public struct SMSpectrumFrame {
    /// Normalized 0...1 magnitudes per band, length == `SMConfiguration.bandCount`.
    public let magnitudes: [Float]

    /// Sample-time of the frame, in seconds since the start of capture.
    public let timestamp: TimeInterval

    /// Frequency at the center of each band, in Hz. Same length as `magnitudes`.
    public let bandFrequencies: [Float]

    public init(magnitudes: [Float], timestamp: TimeInterval, bandFrequencies: [Float]) {
        self.magnitudes = magnitudes
        self.timestamp = timestamp
        self.bandFrequencies = bandFrequencies
    }
}
