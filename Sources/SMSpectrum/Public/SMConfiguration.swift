import Foundation
import CoreGraphics
import SMSpectrumRenderer

/// Top-level configuration for `SMSpectrumView`.
public struct SMConfiguration: Equatable {
    public var style: SMStyle
    public var frequencyRange: ClosedRange<Float>
    public var bandCount: Int
    public var fftSize: SMFFTSize
    public var maxHeight: CGFloat
    public var thickness: CGFloat
    public var softness: Float
    public var path: SMPath
    public var gradient: SMColorGradient
    public var sideMode: SMSide
    public var smoothing: SMSmoothing

    /// Additional spatial blur strength applied across the band axis (0...1).
    /// 0 = single 3-tap pass (default light smoothing), 1 = up to 4 extra
    /// passes for very smooth, dome-shaped peaks.
    public var bandSmoothing: Float

    /// Fractional gap between adjacent bars (0...1) for bar-style pipelines.
    /// 0 = bars touch (closed ring on circle), 0.5 = each bar fills half its
    /// arc. Currently honored by `circle`; ignored by line/dot styles.
    public var barSpacing: Float

    /// Display variant for the `.circle` style — radial bars (default) or a
    /// smooth Cubic Hermite curve. Ignored by other styles.
    public var circleMode: SMCircleMode

    /// Inner ring radius (points) for `.circleHermite` mode. The curve sits
    /// at this radius at silence and extends outward by up to `maxHeight` at
    /// full magnitude. Ignored by other styles/modes.
    public var circleBaseRadius: CGFloat

    /// Layers rendered for this configuration. Each layer is an independent
    /// slice of the path with its own gradient and thickness; see `SMLayer`
    /// for how `range` is interpreted per style. An empty array means "draw
    /// the full path once with the config-level gradient/thickness".
    public var layers: [SMLayer]

    public init(
        style: SMStyle,
        frequencyRange: ClosedRange<Float> = 20...20_000,
        bandCount: Int = 96,
        fftSize: SMFFTSize = .size2048,
        maxHeight: CGFloat = 200,
        thickness: CGFloat = 6,
        softness: Float = 0.3,
        path: SMPath = .line(from: CGPoint(x: 0, y: 0.5), to: CGPoint(x: 1, y: 0.5)),
        gradient: SMColorGradient = .cyanMagenta,
        sideMode: SMSide = .both,
        smoothing: SMSmoothing = .balanced,
        bandSmoothing: Float = 0,
        barSpacing: Float = 0,
        circleMode: SMCircleMode = .bars,
        circleBaseRadius: CGFloat = 80,
        layers: [SMLayer] = []
    ) {
        precondition(bandCount >= 8 && bandCount <= 1024, "bandCount out of range.")
        precondition(frequencyRange.lowerBound > 0, "frequencyRange must be positive.")
        precondition((0...1).contains(bandSmoothing), "bandSmoothing must be in 0...1.")
        precondition((0...1).contains(barSpacing), "barSpacing must be in 0...1.")
        self.style = style
        self.frequencyRange = frequencyRange
        self.bandCount = bandCount
        self.fftSize = fftSize
        self.maxHeight = maxHeight
        self.thickness = thickness
        self.softness = softness
        self.path = path
        self.gradient = gradient
        self.sideMode = sideMode
        self.smoothing = smoothing
        self.bandSmoothing = bandSmoothing
        self.barSpacing = barSpacing
        self.circleMode = circleMode
        self.circleBaseRadius = circleBaseRadius
        self.layers = layers
    }
}

extension SMConfiguration {
    public static let digital = SMConfiguration(
        style: .digital,
        bandCount: 96,
        maxHeight: 280,
        thickness: 3,
        softness: 0.4,
        smoothing: .smooth
    )
    public static let analogLines = SMConfiguration(
        style: .analogLines,
        bandCount: 128,
        maxHeight: 240,
        thickness: 1.5,
        softness: 0.3,
        smoothing: .smooth
    )
    public static let analogDots = SMConfiguration(
        style: .analogDots,
        bandCount: 96,
        maxHeight: 240,
        thickness: 5,
        softness: 0.6
    )

    public static let circle = SMConfiguration(
        style: .circle,
        bandCount: 128,
        maxHeight: 280,
        thickness: 0,
        softness: 0.6,
        sideMode: .sideA,
        smoothing: .silky,
        bandSmoothing: 0.7
    )

    public static let lineGradient = SMConfiguration(
        style: .lineGradient,
        bandCount: 128,
        maxHeight: 280,
        thickness: 0,
        softness: 0.6,
        sideMode: .sideA,
        smoothing: .silky,
        bandSmoothing: 0.7
    )

    /// Time-domain-style waveform: thin solid line on a flat baseline with
    /// sharp transient peaks. Uses snappy smoothing so peaks register
    /// immediately rather than being averaged out.
    public static let waveform = SMConfiguration(
        style: .waveform,
        bandCount: 256,
        maxHeight: 80,
        thickness: 1.5,
        softness: 0,
        gradient: SMColorGradient(colors: [.white, .white]),
        sideMode: .sideA,
        smoothing: .snappy
    )
}

extension SMConfiguration {
    /// Converts this configuration into the renderer-side descriptor.
    func renderStyleDescriptor() -> RenderStyleDescriptor {
        RenderStyleDescriptor(
            style: style.renderStyle(circleMode: circleMode),
            path: path.renderPath,
            sideMode: sideMode.renderSideMode,
            gradient: gradient.renderGradient,
            maxHeight: maxHeight,
            thickness: thickness,
            softness: softness,
            barSpacing: barSpacing,
            circleBaseRadius: circleBaseRadius,
            layers: layers.map { $0.renderLayer() }
        )
    }
}

extension SMConfiguration {
    /// Convenience preset: full-circle Cubic Hermite split into 4 quadrants,
    /// each quadrant carrying a different gradient.
    ///
    /// The radial budget is tuned so audio bumps stay around 25% of the base
    /// ring (`maxHeight = 30` vs `circleBaseRadius = 120`) — peaks read as
    /// waves on a clearly circular outline rather than radial spikes.
    public static let circleHermite: SMConfiguration = {
        let twoPi = CGFloat.pi * 2
        return SMConfiguration(
            style: .circle,
            bandCount: 128,
            maxHeight: 30,
            thickness: 0,
            softness: 0.6,
            sideMode: .sideA,
            smoothing: .silky,
            bandSmoothing: 0.7,
            circleMode: .cubicHermite,
            circleBaseRadius: 120,
            layers: [
                SMLayer(range: 0...(twoPi * 0.25),             gradient: .rainbow,     thickness: 2),
                SMLayer(range: (twoPi * 0.25)...(twoPi * 0.5), gradient: .warmSunset,  thickness: 2),
                SMLayer(range: (twoPi * 0.5)...(twoPi * 0.75), gradient: .cyanMagenta, thickness: 2),
                SMLayer(range: (twoPi * 0.75)...twoPi,         gradient: .rainbow,     thickness: 2)
            ]
        )
    }()

    /// Convenience preset: time-domain waveform drawn as a closed circle with
    /// snappy smoothing — sharp transient peaks travel around the ring.
    public static let circleWaveform: SMConfiguration = {
        let twoPi = CGFloat.pi * 2
        return SMConfiguration(
            style: .circle,
            bandCount: 256,
            maxHeight: 25,
            thickness: 0,
            softness: 0,
            gradient: SMColorGradient(colors: [.white, .white]),
            sideMode: .sideA,
            smoothing: .snappy,
            circleMode: .cubicHermite,
            circleBaseRadius: 130,
            layers: [
                SMLayer(
                    range: 0...twoPi,
                    gradient: SMColorGradient(colors: [.white, .white]),
                    thickness: 1.4
                )
            ]
        )
    }()
}
