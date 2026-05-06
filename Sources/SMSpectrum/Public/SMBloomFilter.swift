import Foundation

/// Optional post-process bloom applied after the spectrum is drawn.
///
/// When set on `SMConfiguration.bloomFilter`, the spectrum renders into an
/// offscreen texture; bright pixels (luminance above `threshold`) are
/// gaussian-blurred at half-resolution and additively composited back into
/// the drawable. Applies to every render style — not just the circle styles.
public struct SMBloomFilter: Equatable {

    /// Strength of the blurred bright pass added to the final image.
    /// 0 = bloom invisible, 1 = standard bloom, > 1 = overdrive.
    public var intensity: Float

    /// Luminance threshold (0...1). Pixels brighter than this contribute to
    /// bloom; 0 means everything blooms, 1 means nothing does.
    public var threshold: Float

    /// Blur radius in points. Larger values produce softer, wider bloom at
    /// modest extra cost.
    public var radius: Float

    public init(
        intensity: Float = 0.6,
        threshold: Float = 0.5,
        radius: Float = 12
    ) {
        precondition(intensity >= 0, "bloom intensity must be >= 0.")
        precondition((0...1).contains(threshold), "bloom threshold must be in 0...1.")
        precondition(radius > 0, "bloom radius must be > 0.")
        self.intensity = intensity
        self.threshold = threshold
        self.radius = radius
    }

    public static let soft   = SMBloomFilter(intensity: 0.4, threshold: 0.55, radius: 10)
    public static let neon   = SMBloomFilter(intensity: 0.9, threshold: 0.4,  radius: 16)
    public static let dreamy = SMBloomFilter(intensity: 1.2, threshold: 0.3,  radius: 24)
}
