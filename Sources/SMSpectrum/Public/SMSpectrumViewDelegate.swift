import Foundation

/// Delegate callbacks for `SMSpectrumView`.
public protocol SMSpectrumViewDelegate: AnyObject {

    /// Called on the main queue with each newly analyzed frame.
    func spectrumView(_ view: SMSpectrumView, didProduce frame: SMSpectrumFrame)

    /// Called on the main queue with the bass energy level (0…1)
    /// derived from the lowest-frequency bands. Use this to drive
    /// audio-reactive animations (album art pulse, etc).
    func spectrumView(_ view: SMSpectrumView, didUpdateBassLevel level: Float)

    /// Called on the main queue with bass, mid, and treble energy.
    /// `bass`: lowest 15 % of bands, `mid`: 15–50 %, `treble`: 50–100 %.
    /// Use to drive richer frequency-synced animations.
    func spectrumView(_ view: SMSpectrumView, didUpdateSpectrum bass: Float, mid: Float, treble: Float)

    /// Called on the main queue when an unrecoverable error occurs.
    func spectrumView(_ view: SMSpectrumView, didFailWith error: SMError)
}

public extension SMSpectrumViewDelegate {
    func spectrumView(_ view: SMSpectrumView, didProduce frame: SMSpectrumFrame) {}
    func spectrumView(_ view: SMSpectrumView, didUpdateBassLevel level: Float) {}
    func spectrumView(_ view: SMSpectrumView, didUpdateSpectrum bass: Float, mid: Float, treble: Float) {}
    func spectrumView(_ view: SMSpectrumView, didFailWith error: SMError) {}
}
