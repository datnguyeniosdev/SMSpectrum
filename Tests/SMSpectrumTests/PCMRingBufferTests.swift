import XCTest
@testable import SMSpectrum

final class PCMRingBufferTests: XCTestCase {

    func testWriteAndPeekRoundTrip() {
        let buffer = PCMRingBuffer(capacity: 8)
        var input: [Float] = [1, 2, 3, 4]
        input.withUnsafeBufferPointer { ptr in
            buffer.write(ptr.baseAddress!, count: ptr.count)
        }

        var out = [Float](repeating: 0, count: 4)
        let read = out.withUnsafeMutableBufferPointer { ptr in
            buffer.peek(into: ptr.baseAddress!, count: 4)
        }
        XCTAssertEqual(read, 4)
        XCTAssertEqual(out, [1, 2, 3, 4])
    }

    func testOverflowDropsOldestSamples() {
        let buffer = PCMRingBuffer(capacity: 4)
        var input: [Float] = [1, 2, 3, 4, 5, 6]
        input.withUnsafeBufferPointer { ptr in
            buffer.write(ptr.baseAddress!, count: ptr.count)
        }
        XCTAssertLessThanOrEqual(buffer.availableForRead, 4)
    }
}
