import Foundation
import CoreGraphics

/// A single frame of pre-computed spectrum data ready for rendering.
///
/// The renderer is intentionally agnostic of the audio domain: it consumes
/// normalized magnitudes and a style descriptor. This separation lets the
/// renderer be reused by realtime playback (`MTKView`) and offline export
/// (`AVAssetWriter` + offscreen `MTLTexture`) without coupling.
public struct RenderFrame {
    /// Normalized magnitudes per band, 0...1.
    public let magnitudes: [Float]

    /// Wall-clock timestamp of the frame, used for time-dependent effects.
    public let timestamp: CFTimeInterval

    /// Visual configuration for this frame.
    public let style: RenderStyleDescriptor

    public init(
        magnitudes: [Float],
        timestamp: CFTimeInterval,
        style: RenderStyleDescriptor
    ) {
        self.magnitudes = magnitudes
        self.timestamp = timestamp
        self.style = style
    }
}
