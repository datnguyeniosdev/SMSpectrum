import Foundation
import AVFoundation
import Accelerate

/// Performs windowed FFT on PCM input and returns log-magnitudes per FFT bin.
///
/// This class is intended to run on a dedicated DSP queue, not the audio
/// thread. It owns mutable scratch buffers; not thread-safe across queues.
final class FFTProcessor {

    var fftSize: SMFFTSize {
        didSet {
            guard fftSize != oldValue else { return }
            rebuild()
        }
    }

    private var fftSetup: vDSP_DFT_Setup?
    private var window: WindowFunction
    private var realIn: [Float]
    private var imagIn: [Float]
    private var realOut: [Float]
    private var imagOut: [Float]
    private var magnitudes: [Float]

    init(fftSize: SMFFTSize) {
        self.fftSize = fftSize
        self.window = WindowFunction(kind: .hann, length: fftSize.rawValue)
        let n = fftSize.rawValue
        self.realIn = [Float](repeating: 0, count: n)
        self.imagIn = [Float](repeating: 0, count: n)
        self.realOut = [Float](repeating: 0, count: n)
        self.imagOut = [Float](repeating: 0, count: n)
        self.magnitudes = [Float](repeating: 0, count: n / 2)
        self.fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(n), .FORWARD)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    /// Processes the first channel of `buffer` and returns half-spectrum
    /// log-magnitudes (length `fftSize/2`). Returns an empty array if the
    /// buffer is unsupported.
    func process(buffer: AVAudioPCMBuffer, sampleRate: Double) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let frameCount = Int(buffer.frameLength)
        let n = fftSize.rawValue
        guard frameCount > 0 else { return [] }

        // Copy up to n samples from channel 0; zero-pad the rest.
        let copyCount = min(frameCount, n)
        memcpy(&realIn, channelData[0], copyCount * MemoryLayout<Float>.size)
        if copyCount < n {
            for i in copyCount..<n {
                realIn[i] = 0
            }
        }

        // Apply window in-place.
        realIn.withUnsafeMutableBufferPointer { ptr in
            if let base = ptr.baseAddress {
                window.apply(to: base, count: n)
            }
        }
        // Zero imaginary input.
        for i in 0..<n { imagIn[i] = 0 }

        guard let setup = fftSetup else { return [] }
        vDSP_DFT_Execute(setup, realIn, imagIn, &realOut, &imagOut)

        // Compute magnitudes for the lower half (positive frequencies).
        let half = n / 2
        var split = DSPSplitComplex(realp: &realOut, imagp: &imagOut)
        vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(half))

        // Normalize then convert to dB-style log scale.
        var scale = Float(2.0) / Float(n)
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(half))
        var floor: Float = 1e-7
        vDSP_vsadd(magnitudes, 1, &floor, &magnitudes, 1, vDSP_Length(half))

        var result = [Float](repeating: 0, count: half)
        var halfCount = Int32(half)
        vvlog10f(&result, magnitudes, &halfCount)
        // Map a 60 dB log10 window (-3 ... 0) to 0...1. A tighter window than
        // a "full" 140 dB range gives quiet bands real headroom near 0 and
        // pushes peaks to ~1, so the visual dynamic range is far more
        // legible — quiet sections look quiet, loud peaks pop.
        var addend: Float = 3.0
        var divisor: Float = 3.0
        vDSP_vsadd(result, 1, &addend, &result, 1, vDSP_Length(half))
        vDSP_vsdiv(result, 1, &divisor, &result, 1, vDSP_Length(half))
        var minVal: Float = 0
        var maxVal: Float = 1
        vDSP_vclip(result, 1, &minVal, &maxVal, &result, 1, vDSP_Length(half))

        _ = sampleRate
        return result
    }

    private func rebuild() {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
            fftSetup = nil
        }
        let n = fftSize.rawValue
        window = WindowFunction(kind: .hann, length: n)
        realIn = [Float](repeating: 0, count: n)
        imagIn = [Float](repeating: 0, count: n)
        realOut = [Float](repeating: 0, count: n)
        imagOut = [Float](repeating: 0, count: n)
        magnitudes = [Float](repeating: 0, count: n / 2)
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(n), .FORWARD)
    }
}
