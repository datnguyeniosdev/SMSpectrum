import XCTest
@testable import SMSpectrum

final class SMConfigurationTests: XCTestCase {

    func testPresetsAreDistinct() {
        XCTAssertNotEqual(SMConfiguration.digital, SMConfiguration.analogLines)
        XCTAssertNotEqual(SMConfiguration.analogLines, SMConfiguration.analogDots)
    }

    func testRenderStyleDescriptorReflectsConfiguration() {
        let config = SMConfiguration(style: .digital, bandCount: 64, maxHeight: 100, thickness: 4, softness: 0.2)
        let descriptor = config.renderStyleDescriptor()
        XCTAssertEqual(descriptor.maxHeight, 100)
        XCTAssertEqual(descriptor.thickness, 4)
        XCTAssertEqual(descriptor.softness, 0.2)
    }
}
