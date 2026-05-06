import Foundation

/// FFT window size. Larger sizes give finer frequency resolution at the cost
/// of higher latency.
public enum SMFFTSize: Int, CaseIterable {
    case size512 = 512
    case size1024 = 1024
    case size2048 = 2048
    case size4096 = 4096

    /// `log2` of the size, required by `vDSP_fft_zrip`.
    public var log2Size: Int {
        switch self {
        case .size512: return 9
        case .size1024: return 10
        case .size2048: return 11
        case .size4096: return 12
        }
    }
}
