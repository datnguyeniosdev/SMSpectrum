import XCTest
@testable import SMSpectrum

final class BandMapperTests: XCTestCase {

    func testCenterFrequenciesAreLogarithmicallySpaced() {
        let mapper = BandMapper(bandCount: 4, frequencyRange: 100...1600)
        let centers = mapper.bandCenterFrequencies(sampleRate: 44_100)

        XCTAssertEqual(centers.count, 4)
        // Ratios between consecutive centers should be approximately equal in log space.
        let ratios = zip(centers.dropFirst(), centers).map { $0 / $1 }
        let firstRatio = ratios[0]
        for ratio in ratios.dropFirst() {
            XCTAssertEqual(ratio, firstRatio, accuracy: 0.05)
        }
    }

    func testMapToBandsReturnsRequestedSize() {
        let mapper = BandMapper(bandCount: 16, frequencyRange: 20...20_000)
        let mags = (0..<1024).map { Float($0) / 1024.0 }
        let banded = mapper.mapToBands(magnitudes: mags, sampleRate: 44_100, fftSize: 2048)
        XCTAssertEqual(banded.count, 16)
    }
}
