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
    private var globalMaxMagnitude: Float = 0.5
    private var lastProcessTime: TimeInterval = 0
    private var previousPeaks: [SmoothedPeak] = []

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
        let isCircleStyle = (configuration.style == .circle || configuration.style == .circleLine)
        let resolved = isCircleStyle && configuration.circleMirror > 0
            ? processCircleSpectrum(magnitudes, timestamp: timestamp)
            : magnitudes
        return RenderFrame(
            magnitudes: resolved,
            timestamp: timestamp,
            style: configuration.renderStyleDescriptor()
        )
    }

    /// Mirrors → smooth vertical reference → phase → peak detection →
    /// Mirrors → global reference → phase → detect peaks →
    /// smooth peak positions with inertia → envelope → taper.
    private func processCircleSpectrum(_ magnitudes: [Float], timestamp: TimeInterval) -> [Float] {
        guard !magnitudes.isEmpty else { return magnitudes }

        let dt = max(0.001, timestamp - lastProcessTime)
        lastProcessTime = timestamp

        let frameMax = magnitudes.max() ?? 0
        let attack: Float  = 0.55   // fast rise for quick transients
        let release: Float = 0.08   // faster decay for fast-paced music
        let smoothAlpha = frameMax > globalMaxMagnitude ? attack : release
        globalMaxMagnitude += (frameMax - globalMaxMagnitude) * (1.0 - exp(-Float(dt) / (1.0 / smoothAlpha)))
        let reference = max(globalMaxMagnitude, 0.05)

        // — 1. Mirror —————————————————————————————————————————
        var data = magnitudes
        let n = data.count

        // — 2. Normalize ——————————————————————————————————————
        for i in 0..<n { data[i] = min(data[i] / reference, 1.0) }

        // — 3. Phase shift ————————————————————————————————————
        let phase = configuration.circleMirrorPhase
        if phase != 0 {
            let offset = Int((phase * Float(n)).rounded()) % n
            if offset != 0 {
                let pos = offset < 0 ? n + offset : offset
                let split = n - pos
                data = Array(data[split...]) + Array(data[..<split])
            }
        }

        // — 4. Detect raw peaks ———————————————————————————————
        let maxPeaks = configuration.circleMirrorPeaks
        let rawPeaks = findPeaks(data, maxPeaks: maxPeaks)

        // — 5. Smooth with previous frame ————————————————————

        let inertia: Float      = 0.45   // position tracking speed
        let valueInertia: Float  = 0.55   // magnitude tracking speed
        let fadeSpeed: Float     = 0.20   // fade-out for dead peaks
        let matchRadius: Float   = 0.12   // max distance for matching

        var alive = previousPeaks

        for rp in rawPeaks {
            let ri = Float(rp.index) / Float(n - 1) // normalize 0…1
            if let idx = alive.firstIndex(where: { abs($0.normalizedIndex - ri) < matchRadius }) {
                // existing peak – smooth toward new position
                alive[idx].normalizedIndex += (ri - alive[idx].normalizedIndex) * inertia
                alive[idx].value        += (rp.value - alive[idx].value) * valueInertia
                alive[idx].life          = min(alive[idx].life + 0.40, 1.0)
            } else {
                // new peak – spawn
                alive.append(SmoothedPeak(normalizedIndex: ri, value: rp.value, life: 0.5))
            }
        }

        // fade out peaks that weren't matched
        for i in (0..<alive.count).reversed() {
            alive[i].life -= fadeSpeed
            if alive[i].life <= 0 { alive.remove(at: i) }
        }

        // clamp tracked peaks
        alive.sort { $0.value * $0.life > $1.value * $1.life }
        let maxTracked = maxPeaks * 2
        if alive.count > maxTracked { alive = Array(alive.prefix(maxTracked)) }

        previousPeaks = alive

        // — 6. Envelope from smoothed peaks ———————————————————
        var envelope = [Float](repeating: 0, count: n)
        for p in alive {
            let widthFraction = 0.10 + 0.40 * (1.0 - p.value)
            let halfWidth = max(1, Int(widthFraction * Float(n) * 0.5))
            let center = Int(p.normalizedIndex * Float(n - 1))
            let lo = max(0, center - halfWidth)
            let hi = min(n - 1, center + halfWidth)
            for i in lo...hi {
                let t = abs(Float(i - center)) / Float(halfWidth)
                let hill = 0.5 * (1.0 + cos(.pi * t))
                envelope[i] = max(envelope[i], hill * p.value * p.life)
            }
        }

        // — 7. Apply envelope ————————————————————————————————
        for i in 0..<n { data[i] *= envelope[i] }

        // — 8. Tukey seam taper ——————————————————————————————
        let taperAlpha = configuration.circleMirror
        guard taperAlpha > 0, n > 1 else { return data }
        let halfTaper = Int((taperAlpha * 0.5) * Float(n - 1))
        guard halfTaper > 0 else { return data }
        for i in 0..<n {
            let w: Float
            if i < halfTaper {
                w = 0.5 * (1.0 - cos(.pi * Float(i) / Float(halfTaper)))
            } else if i >= n - halfTaper {
                w = 0.5 * (1.0 - cos(.pi * Float(n - 1 - i) / Float(halfTaper)))
            } else {
                w = 1.0
            }
            data[i] *= w
        }
        return data
    }

    // MARK: - Peak tracking

    private struct SmoothedPeak {
        var normalizedIndex: Float // 0…1 along the circle
        var value: Float           // smoothed magnitude
        var life: Float            // 0…1, fades when peak disappears
    }

    // MARK: - Peak detection

    private struct Peak {
        let index: Int
        let value: Float
    }

    /// Finds the strongest local maxima in `data`, up to `maxPeaks`.
    /// Ignores peaks below a noise floor of 0.03.
    private func findPeaks(_ data: [Float], maxPeaks: Int) -> [Peak] {
        var peaks: [Peak] = []
        let n = data.count
        guard n >= 3 else { return peaks }

        for i in 1..<(n - 1) {
            if data[i] > data[i - 1], data[i] > data[i + 1], data[i] > 0.03 {
                peaks.append(Peak(index: i, value: data[i]))
            }
        }

        peaks.sort { $0.value > $1.value }
        let clamped = min(maxPeaks, peaks.count)
        guard clamped < peaks.count else { return peaks }
        return Array(peaks[0..<clamped])
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
