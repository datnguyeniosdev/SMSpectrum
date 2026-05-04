import Foundation
import AVFoundation

/// Input audio source for `SMSpectrumView`.
public enum SMSource {
    /// A local audio file.
    case file(URL)

    /// Microphone input via the shared audio session.
    case microphone

    /// An existing `AVAudioEngine`. Magnitudes are computed from a tap on `node`.
    case audioEngine(AVAudioEngine, node: AVAudioNode)

    /// Manually pushed PCM buffers. The host calls `SMSpectrumView.push(buffer:)`.
    case manual
}
