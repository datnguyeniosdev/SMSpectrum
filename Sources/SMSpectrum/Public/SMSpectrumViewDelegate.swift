import Foundation

/// Delegate callbacks for `SMSpectrumView`.
public protocol SMSpectrumViewDelegate: AnyObject {

    /// Called on the main queue with each newly analyzed frame.
    func spectrumView(_ view: SMSpectrumView, didProduce frame: SMSpectrumFrame)

    /// Called on the main queue when an unrecoverable error occurs.
    func spectrumView(_ view: SMSpectrumView, didFailWith error: SMError)
}

public extension SMSpectrumViewDelegate {
    func spectrumView(_ view: SMSpectrumView, didProduce frame: SMSpectrumFrame) {}
    func spectrumView(_ view: SMSpectrumView, didFailWith error: SMError) {}
}
