import Foundation

/// Reduces a half-spectrum FFT magnitude array down to `bandCount` bands using
/// logarithmic frequency bucketing across `frequencyRange`.
struct BandMapper {

    let bandCount: Int
    let frequencyRange: ClosedRange<Float>

    /// Returns the center frequency (Hz) of each band given the FFT sample rate.
    func bandCenterFrequencies(sampleRate: Float) -> [Float] {
        precondition(bandCount > 0)
        let logLow = log(frequencyRange.lowerBound)
        let logHigh = log(min(frequencyRange.upperBound, sampleRate * 0.5))
        let step = (logHigh - logLow) / Float(bandCount)
        return (0..<bandCount).map { i in
            exp(logLow + step * (Float(i) + 0.5))
        }
    }

    /// Maps half-spectrum magnitudes to `bandCount` bands.
    /// `magnitudes.count` is expected to be `fftSize / 2`.
    func mapToBands(magnitudes: [Float], sampleRate: Float, fftSize: Int) -> [Float] {
        guard !magnitudes.isEmpty else { return [Float](repeating: 0, count: bandCount) }

        let nyquist = sampleRate * 0.5
        let binResolution = nyquist / Float(magnitudes.count)
        let logLow = log(frequencyRange.lowerBound)
        let logHigh = log(min(frequencyRange.upperBound, nyquist))
        let step = (logHigh - logLow) / Float(bandCount)

        var result = [Float](repeating: 0, count: bandCount)
        for band in 0..<bandCount {
            let fLow = exp(logLow + step * Float(band))
            let fHigh = exp(logLow + step * Float(band + 1))
            let binLow = max(0, Int(fLow / binResolution))
            let binHigh = min(magnitudes.count - 1, max(binLow, Int(fHigh / binResolution)))

            var maxMag: Float = 0
            for bin in binLow...binHigh {
                if magnitudes[bin] > maxMag {
                    maxMag = magnitudes[bin]
                }
            }
            result[band] = maxMag
        }
        _ = fftSize
        return result
    }
}
