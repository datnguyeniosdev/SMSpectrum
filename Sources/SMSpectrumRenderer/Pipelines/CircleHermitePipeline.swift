import Foundation
import Metal
import simd

private struct CircleHermiteUniforms {
    var viewportSize: SIMD2<Float>  //  0..8
    var time: Float                  //  8..12
    var baseRadius: Float            // 12..16
    var maxHeight: Float             // 16..20
    var startAngle: Float            // 20..24
    var endAngle: Float              // 24..28
    var angularPhase: Float          // 28..32
    var softness: Float              // 32..36
    var phase: Float                 // 36..40
    var bandCount: Int32             // 40..44
    var stopCount: Int32             // 44..48
    var dynamicPhase: Int32          // 48..52
    var _padding: Float = 0          // 52..56
}

/// Renders the spectrum as a filled donut sector per layer. The fill spans
/// `baseRadius` (inner) to `baseRadius + magnitude * maxHeight` (outer) with
/// alpha fading inward; gradient sweeps along the arc. Mirrors `LineGradient`
/// in polar form. `RenderLayer.thickness` is intentionally ignored — there is
/// no stroke, only fill.
final class CircleHermitePipeline: SpectrumPipeline {

    static let tessellationFactor: Int = 8

    private let pipelineState: MTLRenderPipelineState

    init(library: PipelineLibrary, pixelFormat: MTLPixelFormat) throws {
        let vertex = try library.makeFunction(named: "circleHermiteVertex")
        let fragment = try library.makeFunction(named: "circleHermiteFragment")

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "SMSpectrum.CircleHermite"
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            self.pipelineState = try library.device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw RenderError.pipelineCreationFailed(
                stage: "CircleHermite.pipelineState",
                underlying: error
            )
        }
    }

    func encode(
        frame: RenderFrame,
        viewportSize: SIMD2<Float>,
        bufferPool: BufferPool,
        encoder: MTLRenderCommandEncoder
    ) throws {
        guard frame.magnitudes.count >= 2 else {
            throw RenderError.invalidFrame(reason: "CircleHermite requires at least 2 magnitudes.")
        }
        let layers = frame.style.effectiveLayers

        bufferPool.advance()

        let magnitudeByteCount = MemoryLayout<Float>.stride * frame.magnitudes.count
        let magnitudeBuffer = try bufferPool.buffer(
            forKey: "CircleHermite.magnitudes",
            byteCount: magnitudeByteCount
        )
        _ = frame.magnitudes.withUnsafeBufferPointer { ptr in
            memcpy(magnitudeBuffer.contents(), ptr.baseAddress, magnitudeByteCount)
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(magnitudeBuffer, offset: 0, index: 0)

        let totalSamples = max(frame.magnitudes.count * Self.tessellationFactor, 3)
        let vertexCount = (totalSamples + 1) * 2

        for (layerIndex, layer) in layers.enumerated() {
            let stops = layer.gradient.stops
            let stopByteCount = MemoryLayout<SIMD4<Float>>.stride * stops.count
            let stopBuffer = try bufferPool.buffer(
                forKey: "CircleHermite.stops.\(layerIndex)",
                byteCount: stopByteCount
            )
            _ = stops.withUnsafeBufferPointer { ptr in
                memcpy(stopBuffer.contents(), ptr.baseAddress, stopByteCount)
            }

            var uniforms = CircleHermiteUniforms(
                viewportSize: viewportSize,
                time: Float(frame.timestamp),
                baseRadius: Float(frame.style.circleBaseRadius + layer.radialOffset),
                maxHeight: Float(frame.style.maxHeight),
                startAngle: Float(layer.range.lowerBound),
                endAngle: Float(layer.range.upperBound),
                angularPhase: Float(layer.angularPhase),
                softness: frame.style.softness,
                phase: layer.gradient.dynamicPhase
                    ? Float(frame.timestamp) * layer.gradient.phaseSpeed
                    : 0,
                bandCount: Int32(frame.magnitudes.count),
                stopCount: Int32(stops.count),
                dynamicPhase: layer.gradient.dynamicPhase ? 1 : 0
            )

            encoder.setVertexBytes(&uniforms, length: MemoryLayout<CircleHermiteUniforms>.stride, index: 1)
            encoder.setFragmentBuffer(stopBuffer, offset: 0, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CircleHermiteUniforms>.stride, index: 1)
            encoder.drawPrimitives(
                type: .triangleStrip,
                vertexStart: 0,
                vertexCount: vertexCount
            )
        }
    }
}
