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

    /// Override dot radius (points). When nil, falls back to `thickness`.
    /// Used by `.analogDots`.
    public var dotRadius: CGFloat?

    /// Override bar width (points). When nil, falls back to `thickness`.
    /// Used by `.digital`.
    public var barWidth: CGFloat?

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

    /// Optional post-process bloom filter. When non-nil, the spectrum is
    /// drawn into an offscreen texture and a gaussian bloom is composited
    /// on top before reaching the drawable. Style-agnostic.
    public var bloomFilter: SMBloomFilter?

    /// Mirror + taper for circle styles (0...1). When > 0, the magnitude
    /// array is mirrored into `[low...high...low]` then a smooth taper is
    /// applied to both ends: `circleMirror / 2` fraction at the start and
    /// `circleMirror / 2` fraction at the end fade from/to zero via a
    /// smoothstep curve. The middle `1 - circleMirror` portion passes through
    /// untouched. 0 = off (linear band distribution). Ignored by non-circle
    /// styles. For example, 0.4 means 20 % taper at each end, 60 % real in
    /// the middle.
    public var circleMirror: Float

    /// Rotates the mirrored spectrum around the circle (0...1, normalized).
    /// 0 = low frequencies at 0°/360° seam, high frequencies at 180°.
    /// 0.5 = high frequencies at the seam, low frequencies opposite.
    /// Ignored when `circleMirror == 0` or style is not `.circle`.
    public var circleMirrorPhase: Float

    /// Maximum number of visible peaks on the circle when `circleMirror > 0`
    /// (1…6). Fewer peaks will appear if the audio doesn't produce enough
    /// strong frequency clusters.
    public var circleMirrorPeaks: Int

    /// When true, magnitudes are run through the same processing pipeline
    /// used by circle styles (peak detection, envelope, taper) before
    /// reaching the shader — for any style, not just circle. When false
    /// (default), raw smoothed magnitudes are passed directly. Use this to
    /// toggle between raw FFT data and enhanced/cooked display.
    public var processedData: Bool

    /// Orientation of the band axis for line-based styles. Default
    /// `.horizontal` (bands left → right). Set `.vertical` to run bands
    /// top → bottom with bars extending horizontally. Circle styles ignore
    /// this option.
    public var orientation: SMOrientation

    public init(
        style: SMStyle,
        frequencyRange: ClosedRange<Float> = 20...20_000,
        bandCount: Int = 96,
        fftSize: SMFFTSize = .size2048,
        maxHeight: CGFloat = 200,
        thickness: CGFloat = 6,
        softness: Float = 0.3,
        dotRadius: CGFloat? = nil,
        barWidth: CGFloat? = nil,
        path: SMPath = .line(from: CGPoint(x: 0, y: 0.5), to: CGPoint(x: 1, y: 0.5)),
        gradient: SMColorGradient = .cyanMagenta,
        sideMode: SMSide = .both,
        smoothing: SMSmoothing = .balanced,
        bandSmoothing: Float = 0,
        barSpacing: Float = 0,
        circleMode: SMCircleMode = .bars,
        circleBaseRadius: CGFloat = 80,
        layers: [SMLayer] = [],
        bloomFilter: SMBloomFilter? = nil,
        circleMirror: Float = 0,
        circleMirrorPhase: Float = 0,
        circleMirrorPeaks: Int = 4,
        processedData: Bool = false,
        orientation: SMOrientation = .horizontal
    ) {
        precondition(bandCount >= 8 && bandCount <= 1024, "bandCount out of range.")
        precondition(frequencyRange.lowerBound > 0, "frequencyRange must be positive.")
        precondition((0...1).contains(bandSmoothing), "bandSmoothing must be in 0...1.")
        precondition((0...1).contains(barSpacing), "barSpacing must be in 0...1.")
        precondition((0...1).contains(circleMirror), "circleMirror must be in 0...1.")
        precondition((0...1).contains(circleMirrorPhase), "circleMirrorPhase must be in 0...1.")
        precondition((1...6).contains(circleMirrorPeaks), "circleMirrorPeaks must be in 1...6.")
        self.style = style
        self.frequencyRange = frequencyRange
        self.bandCount = bandCount
        self.fftSize = fftSize
        self.maxHeight = maxHeight
        self.thickness = thickness
        self.softness = softness
        self.dotRadius = dotRadius
        self.barWidth = barWidth
        self.path = path
        self.gradient = gradient
        self.sideMode = sideMode
        self.smoothing = smoothing
        self.bandSmoothing = bandSmoothing
        self.barSpacing = barSpacing
        self.circleMode = circleMode
        self.circleBaseRadius = circleBaseRadius
        self.layers = layers
        self.bloomFilter = bloomFilter
        self.circleMirror = circleMirror
        self.circleMirrorPhase = circleMirrorPhase
        self.circleMirrorPeaks = circleMirrorPeaks
        self.processedData = processedData
        self.orientation = orientation
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

    /// Symmetric circle bars with mirror + Tukey window (peak at 9 o'clock,
    /// 25 % taper) and a subtle bloom glow. High frequencies cluster in the
    /// middle of the arc; low frequencies fade at the 0°/360° seam.
    public static let circleMirrored = SMConfiguration(
        style: .circle,
        bandCount: 128,
        maxHeight: 120,
        thickness: 1.5,
        softness: 0.5,
        path: .circle(center: CGPoint(x: 0.5, y: 0.5), radius: 0.4),
        gradient: .cyanMagenta,
        sideMode: .sideA,
        smoothing: .silky,
        bandSmoothing: 0.6,
        circleMode: .bars,
        circleBaseRadius: 100,
        bloomFilter: SMBloomFilter(intensity: 0.5, threshold: 0.3, radius: 12),
        circleMirror: 0.25,
        circleMirrorPhase: 0
    )

    /// Symmetric circle Cubic Hermite curve with mirror + Tukey window
    /// (peak at 9 o'clock, 25 % taper) and bloom glow. A single smooth ring
    /// curve with one visible peak — clean circular silhouette.
    public static let circleHermiteMirrored: SMConfiguration = {
        let twoPi = CGFloat.pi * 2
        return SMConfiguration(
            style: .circle,
            bandCount: 128,
            maxHeight: 80,
            thickness: 0,
            softness: 0.5,
            path: .circle(center: CGPoint(x: 0.5, y: 0.5), radius: 0.4),
            gradient: .cyanMagenta,
            sideMode: .sideA,
            smoothing: .silky,
            bandSmoothing: 0.6,
            circleMode: .cubicHermite,
            circleBaseRadius: 130,
            layers: [
                SMLayer(
                    range: 0...twoPi,
                    gradient: .cyanMagenta,
                    thickness: 1.5
                )
            ],
            bloomFilter: SMBloomFilter(intensity: 0.5, threshold: 0.3, radius: 12),
            circleMirror: 0.25,
            circleMirrorPhase: 0
        )
    }()

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

    /// Circular stroke only — no fill, just a thick line tracing magnitudes
    /// around the ring with gradient coloring.
    public static let circleLine = SMConfiguration(
        style: .circleLine,
        bandCount: 128,
        maxHeight: 80,
        thickness: 2,
        softness: 0.4,
        path: .circle(center: CGPoint(x: 0.5, y: 0.5), radius: 0.4),
        gradient: .cyanMagenta,
        sideMode: .sideA,
        smoothing: .silky,
        bandSmoothing: 0.6,
        circleBaseRadius: 120
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
    /// Center frequency (Hz) of each band for a given sample rate, computed
    /// from `bandCount` and `frequencyRange` using the same log-band layout
    /// the audio engine uses internally. Useful when feeding the view
    /// custom magnitudes — call this once to know which Hz each magnitude
    /// slot corresponds to, then push your data with matching ordering.
    public func bandCenterFrequencies(sampleRate: Float = 44_100) -> [Float] {
        BandMapper(bandCount: bandCount, frequencyRange: frequencyRange)
            .bandCenterFrequencies(sampleRate: sampleRate)
    }
}

extension SMConfiguration {
    /// Converts this configuration into the renderer-side descriptor.
    func renderStyleDescriptor() -> RenderStyleDescriptor {
        let effectiveThickness: CGFloat
        switch style {
        case .analogDots:
            effectiveThickness = dotRadius ?? thickness
        case .digital:
            effectiveThickness = barWidth ?? thickness
        default:
            effectiveThickness = thickness
        }
        return RenderStyleDescriptor(
            style: style.renderStyle(circleMode: circleMode),
            path: path.renderPath,
            sideMode: sideMode.renderSideMode,
            gradient: gradient.renderGradient,
            maxHeight: maxHeight,
            thickness: effectiveThickness,
            softness: softness,
            barSpacing: barSpacing,
            circleBaseRadius: circleBaseRadius,
            layers: layers.map { $0.renderLayer() },
            bloomFilter: bloomFilter.map {
                RenderBloomFilter(
                    intensity: $0.intensity,
                    threshold: $0.threshold,
                    radius: $0.radius
                )
            },
            orientation: orientation.renderOrientation
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
