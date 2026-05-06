import Foundation
import Accelerate

/// Precomputed window function for FFT input.
final class WindowFunction {

    enum Kind {
        case hann
        case hamming
        case blackman
    }

    private(set) var values: [Float]
    let kind: Kind

    init(kind: Kind, length: Int) {
        self.kind = kind
        self.values = [Float](repeating: 0, count: length)
        switch kind {
        case .hann:
            vDSP_hann_window(&values, vDSP_Length(length), Int32(vDSP_HANN_NORM))
        case .hamming:
            vDSP_hamm_window(&values, vDSP_Length(length), 0)
        case .blackman:
            vDSP_blkman_window(&values, vDSP_Length(length), 0)
        }
    }

    /// Multiplies `samples` (length must equal `values.count`) in place.
    func apply(to samples: UnsafeMutablePointer<Float>, count: Int) {
        guard count == values.count else { return }
        vDSP_vmul(samples, 1, values, 1, samples, 1, vDSP_Length(count))
    }
}
