import XCTest
import Metal
@testable import SMSpectrumRenderer

final class BufferPoolTests: XCTestCase {

    func testBufferGrowsToRequestedSize() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device available on this host.")
        }
        let pool = BufferPool(device: device, capacity: 3)
        let small = try pool.buffer(forKey: "test", byteCount: 64)
        XCTAssertGreaterThanOrEqual(small.length, 64)

        pool.advance()
        let larger = try pool.buffer(forKey: "test", byteCount: 256)
        XCTAssertGreaterThanOrEqual(larger.length, 256)
    }
}
