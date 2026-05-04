import Foundation
import CoreGraphics
import SMSpectrumRenderer

/// Bridges `SMSpectrum`'s domain model to `SMSpectrumRenderer`'s `RenderFrame`.
///
/// Owns:
/// - the `BandMapper` (FFT bin → band reduction)
/// - per-band smoothing state (attack/release one-pole filter)
/// - configuration cache for emitting `RenderStyleDescriptor`
final class RenderFrameBuilder {

    var configuration: SMConfiguration {
        didSet { rebuildIfNeeded(oldValue: oldValue) }
    }

    private var bandMapper: BandMapper
    private var smoothedMagnitudes: [Float]
    private var lastUpdateTime: TimeInterval = 0

    init(configuration: SMConfiguration) {
        self.configuration = configuration
        self.bandMapper = BandMapper(
            bandCount: configuration.bandCount,
            frequencyRange: configuration.frequencyRange
        )
        self.smoothedMagnitudes = [Float](repeating: 0, count: configuration.bandCount)
    }

    /// Reduces FFT magnitudes to bands and applies attack/release smoothing.
    func applySmoothing(magnitudes: [Float]) -> [Float] {
        // Caller may pass either FFT-bin magnitudes or already-banded values.
        let banded: [Float]
        if magnitudes.count == configuration.bandCount {
            banded = magnitudes
        } else {
            banded = bandMapper.mapToBands(
                magnitudes: magnitudes,
                sampleRate: 44_100,
                fftSize: configuration.fftSize.rawValue
            )
        }

        let now = CFAbsoluteTimeGetCurrent()
        let dt = max(0.0001, now - lastUpdateTime)
        lastUpdateTime = now

        let attackAlpha = Float(1 - exp(-dt / configuration.smoothing.attack))
        let releaseAlpha = Float(1 - exp(-dt / configuration.smoothing.release))

        for i in 0..<smoothedMagnitudes.count {
            let target = banded.indices.contains(i) ? banded[i] : 0
            let current = smoothedMagnitudes[i]
            let alpha = target > current ? attackAlpha : releaseAlpha
            smoothedMagnitudes[i] = current + (target - current) * alpha
        }

        return spatiallyBlurred(smoothedMagnitudes)
    }

    /// 3-tap binomial blur [0.25, 0.5, 0.25] across the band axis. Applied
    /// `1 + bandSmoothing*4` times (rounded). At `bandSmoothing = 0` it does
    /// a single light pass to smooth out `BandMapper`'s per-bin max spikes;
    /// at `bandSmoothing = 1` up to 5 passes give very soft, dome-shaped
    /// peaks. Edges clamp to themselves (no wrap) so linear-style spectrums
    /// don't pull their high end toward their low end.
    private func spatiallyBlurred(_ values: [Float]) -> [Float] {
        guard values.count >= 3 else { return values }
        let extraPasses = Int((configuration.bandSmoothing * 4).rounded())
        let totalPasses = 1 + max(0, extraPasses)
        var output = values
        for _ in 0..<totalPasses {
            output = singleBlurPass(output)
        }
        return output
    }

    private func singleBlurPass(_ values: [Float]) -> [Float] {
        var output = values
        for i in 0..<values.count {
            let prev = i > 0 ? values[i - 1] : values[i]
            let next = i < values.count - 1 ? values[i + 1] : values[i]
            output[i] = 0.25 * prev + 0.5 * values[i] + 0.25 * next
        }
        return output
    }

    func bandCenterFrequencies(sampleRate: Float) -> [Float] {
        bandMapper.bandCenterFrequencies(sampleRate: sampleRate)
    }

    func makeRenderFrame(magnitudes: [Float], timestamp: TimeInterval) -> RenderFrame {
        RenderFrame(
            magnitudes: magnitudes,
            timestamp: timestamp,
            style: configuration.renderStyleDescriptor()
        )
    }

    private func rebuildIfNeeded(oldValue: SMConfiguration) {
        if oldValue.bandCount != configuration.bandCount
            || oldValue.frequencyRange != configuration.frequencyRange {
            bandMapper = BandMapper(
                bandCount: configuration.bandCount,
                frequencyRange: configuration.frequencyRange
            )
            smoothedMagnitudes = [Float](repeating: 0, count: configuration.bandCount)
        }
    }
}
