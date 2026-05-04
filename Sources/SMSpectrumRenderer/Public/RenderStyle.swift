import CoreGraphics

/// Visual rendering style applied to a `RenderFrame`.
///
/// Mirrors the three display options of After Effects' Audio Spectrum effect.
public enum RenderStyle: Equatable {
    /// Vertical bars per band. Highest performance.
    case digitalBars

    /// Continuous polyline with optional softness/glow.
    case analogLines

    /// Discrete circular dots per band.
    case analogDots

    /// Bars radiating outward from a circle. Bands are distributed evenly around 360°.
    case circleBars

    /// Smooth closed Cubic Hermite curve through band magnitudes. Renders one
    /// curve per layer in `RenderStyleDescriptor.layers`, each with its
    /// own arc, gradient, and stroke thickness.
    case circleHermite

    /// Filled area under the magnitude curve with a horizontal hue gradient
    /// and vertical alpha fade to baseline.
    case lineGradient
}

/// Side mirroring mode (matches After Effects' Side Options).
public enum RenderSideMode: Equatable {
    /// Magnitudes drawn on side A only (typically above/leading).
    case sideA
    /// Magnitudes drawn on side B only (typically below/trailing).
    case sideB
    /// Mirrored on both sides.
    case both
}

/// Color configuration consumed by the renderer.
public struct RenderColorGradient: Equatable {
    /// RGBA stops, normalized 0...1.
    public var stops: [SIMD4<Float>]

    /// When true, the gradient phase rotates over time for animated hue.
    public var dynamicPhase: Bool

    /// Phase rotation speed in cycles per second.
    public var phaseSpeed: Float

    public init(
        stops: [SIMD4<Float>],
        dynamicPhase: Bool = false,
        phaseSpeed: Float = 0.0
    ) {
        precondition(stops.count >= 2, "Gradient requires at least two stops.")
        self.stops = stops
        self.dynamicPhase = dynamicPhase
        self.phaseSpeed = phaseSpeed
    }
}

/// One renderable slice of the path.
///
/// `range` is interpreted by the active style — radians for `.circleBars` /
/// `.circleHermite`, normalized `0...1` along the path for everything else.
/// Each layer renders the **full spectrum** compressed into its segment, so
/// a layer with `range: 0...0.5` shows all `bandCount` bands across the left
/// half of a horizontal display.
///
/// `radialOffset` and `angularPhase` are honored only by `.circleHermite`;
/// other styles ignore them.
public struct RenderLayer: Equatable {
    public var range: ClosedRange<CGFloat>
    public var gradient: RenderColorGradient
    public var thickness: CGFloat
    public var radialOffset: CGFloat
    public var angularPhase: CGFloat

    public init(
        range: ClosedRange<CGFloat>,
        gradient: RenderColorGradient,
        thickness: CGFloat,
        radialOffset: CGFloat = 0,
        angularPhase: CGFloat = 0
    ) {
        self.range = range
        self.gradient = gradient
        self.thickness = thickness
        self.radialOffset = radialOffset
        self.angularPhase = angularPhase
    }
}

/// Geometric layout along which bands are distributed.
public enum RenderPath: Equatable {
    /// Straight line between two normalized points (0...1 coordinate space).
    case line(from: CGPoint, to: CGPoint)

    /// Circle centered at a normalized point with normalized radius.
    case circle(center: CGPoint, radius: CGFloat)

    /// Arbitrary path. The renderer samples points uniformly by arc-length.
    case custom(CGPath)
}

/// Aggregate visual configuration for a single render call.
public struct RenderStyleDescriptor: Equatable {
    public var style: RenderStyle
    public var path: RenderPath
    public var sideMode: RenderSideMode
    public var gradient: RenderColorGradient
    public var maxHeight: CGFloat
    public var thickness: CGFloat
    public var softness: Float

    /// Fractional gap between adjacent bars in bar-style pipelines (currently
    /// `circleBars`). 0 = bars touch, 1 = nothing visible. Other styles ignore.
    public var barSpacing: Float

    /// Inner ring radius (points) for `.circleHermite`. Curve sits here at
    /// silence and extends outward by `maxHeight` at full magnitude.
    public var circleBaseRadius: CGFloat

    /// Layers rendered for this frame. When empty the renderer falls back to
    /// a single layer covering the style's full default range
    /// (`0...2π` for circle styles, `0...1` for everything else) using the
    /// descriptor-level `gradient` and `thickness`.
    public var layers: [RenderLayer]

    public init(
        style: RenderStyle,
        path: RenderPath,
        sideMode: RenderSideMode,
        gradient: RenderColorGradient,
        maxHeight: CGFloat,
        thickness: CGFloat,
        softness: Float,
        barSpacing: Float = 0,
        circleBaseRadius: CGFloat = 80,
        layers: [RenderLayer] = []
    ) {
        self.style = style
        self.path = path
        self.sideMode = sideMode
        self.gradient = gradient
        self.maxHeight = maxHeight
        self.thickness = thickness
        self.softness = softness
        self.barSpacing = barSpacing
        self.circleBaseRadius = circleBaseRadius
        self.layers = layers
    }
}

extension RenderStyleDescriptor {
    /// Fully-resolved layer list ready for the pipeline. Returns the explicit
    /// `layers` when non-empty, otherwise a single fallback layer that spans
    /// the style's natural full range using the descriptor-level gradient and
    /// thickness.
    public var effectiveLayers: [RenderLayer] {
        if !layers.isEmpty { return layers }
        let isCircleStyle = (style == .circleBars || style == .circleHermite)
        let range: ClosedRange<CGFloat> = isCircleStyle
            ? 0...(.pi * 2)
            : 0...1
        return [
            RenderLayer(
                range: range,
                gradient: gradient,
                thickness: thickness
            )
        ]
    }
}
