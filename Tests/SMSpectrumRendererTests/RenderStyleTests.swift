import XCTest
import simd
@testable import SMSpectrumRenderer

final class RenderStyleTests: XCTestCase {

    func testGradientRequiresAtLeastTwoStops() {
        let stops: [SIMD4<Float>] = [
            SIMD4<Float>(1, 0, 0, 1),
            SIMD4<Float>(0, 0, 1, 1)
        ]
        let gradient = RenderColorGradient(stops: stops)
        XCTAssertEqual(gradient.stops.count, 2)
    }

    func testStyleDescriptorEquality() {
        let a = RenderStyleDescriptor(
            style: .digitalBars,
            path: .line(from: .zero, to: CGPoint(x: 1, y: 0)),
            sideMode: .both,
            gradient: RenderColorGradient(stops: [SIMD4<Float>(1,1,1,1), SIMD4<Float>(0,0,0,1)]),
            maxHeight: 100,
            thickness: 4,
            softness: 0.5
        )
        let b = a
        XCTAssertEqual(a, b)
    }
}
