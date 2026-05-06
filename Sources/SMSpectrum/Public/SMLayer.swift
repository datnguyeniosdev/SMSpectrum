import Foundation
import CoreGraphics
import SMSpectrumRenderer

/// Display variant for the `.circle` style.
public enum SMCircleMode: Equatable {
    /// Discrete radial wedges per band (default, original behavior).
    case bars

    /// Smooth Cubic Hermite curve traced over the band magnitudes. Each entry
    /// in `SMConfiguration.layers` draws an angular arc on the same ring
    /// (shared `circleBaseRadius` + `maxHeight`) with its own gradient.
    case cubicHermite
}

/// One renderable layer.
///
/// A configuration with `layers == []` draws the full path once using the
/// config-level `gradient` and `thickness`. With one or more layers, each
/// layer renders an independent slice of the path with its own gradient and
/// thickness — the config-level values are used only as a fallback.
///
/// `range` is interpreted by the active style:
/// - **`.circle`**: angles in radians (CCW from +X). Pass `0...(2π)` for a
///   full ring; partial arcs are valid (e.g. `0...π` for a half-circle).
/// - **All other styles**: normalized position along the path, `0...1`. A
///   layer with `range: 0.25...0.75` occupies the middle 50% of the path.
///
/// Inside its segment, every layer renders the **full spectrum** compressed
/// into the available width/arc — band 0 at `range.lowerBound`, band N-1 at
/// `range.upperBound`.
public struct SMLayer: Equatable {

    /// Range along the path (radians for circle, 0...1 for everything else).
    public var range: ClosedRange<CGFloat>

    /// Color gradient swept across this layer's segment.
    public var gradient: SMColorGradient

    /// Stroke / bar / dot thickness in points for this layer.
    public var thickness: CGFloat

    /// Extra radial offset (points) applied to this layer. Only consumed by
    /// `circle` + `.cubicHermite`. Default 0.
    public var radialOffset: CGFloat

    /// Rotates the spectrum within this layer (radians). Only consumed by
    /// `circle` + `.cubicHermite`. Default 0.
    public var angularPhase: CGFloat

    public init(
        range: ClosedRange<CGFloat>,
        gradient: SMColorGradient,
        thickness: CGFloat = 2,
        radialOffset: CGFloat = 0,
        angularPhase: CGFloat = 0
    ) {
        precondition(thickness > 0, "thickness must be positive.")
        self.range = range
        self.gradient = gradient
        self.thickness = thickness
        self.radialOffset = radialOffset
        self.angularPhase = angularPhase
    }
}

extension SMLayer {
    /// Generates `count` ribbon-style circle layers fanned out across
    /// `radialSpread` (points) and `phaseSpread` (radians). All layers share
    /// the same arc and gradient; offsets are distributed symmetrically
    /// around 0 so the visual center of the ribbon stays on `circleBaseRadius`.
    public static func circleRibbon(
        count: Int,
        radialSpread: CGFloat,
        phaseSpread: CGFloat,
        gradient: SMColorGradient,
        thickness: CGFloat = 0.8,
        arc: ClosedRange<CGFloat> = 0...(.pi * 2)
    ) -> [SMLayer] {
        precondition(count > 0, "ribbon count must be positive.")
        var layers: [SMLayer] = []
        layers.reserveCapacity(count)
        for i in 0..<count {
            let t: CGFloat = count == 1 ? 0.5 : CGFloat(i) / CGFloat(count - 1)
            let centered = t - 0.5
            layers.append(
                SMLayer(
                    range: arc,
                    gradient: gradient,
                    thickness: thickness,
                    radialOffset: centered * radialSpread,
                    angularPhase: centered * phaseSpread
                )
            )
        }
        return layers
    }
}

extension SMLayer {
    func renderLayer() -> RenderLayer {
        RenderLayer(
            range: range,
            gradient: gradient.renderGradient,
            thickness: thickness,
            radialOffset: radialOffset,
            angularPhase: angularPhase
        )
    }
}
