import Foundation
import Metal
import simd

private struct CircleLineUniforms {
    var viewportSize: SIMD2<Float>
    var time: Float
    var baseRadius: Float
    var maxHeight: Float
    var startAngle: Float
    var endAngle: Float
    var softness: Float
    var phase: Float
    var bandCount: Int32
    var stopCount: Int32
    var dynamicPhase: Int32
    var layerThickness: Float
}

/// Renders the spectrum as a circular stroke — thick line tracing the outer
/// edge of the magnitude curve around a ring. No fill, just the line, with
/// wrapped Catmull-Rom interpolation for a smooth closed curve.
/// Iterates `effectiveLayers` so each layer can cover its own arc with its
/// own gradient and thickness.
final class CircleLinePipeline: SpectrumPipeline {

    static let tessellationFactor: Int = 6

    private let pipelineState: MTLRenderPipelineState

    init(library: PipelineLibrary, pixelFormat: MTLPixelFormat) throws {
        let vertex = try library.makeFunction(named: "circleLineVertex")
        let fragment = try library.makeFunction(named: "circleLineFragment")

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "SMSpectrum.CircleLine"
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
                stage: "CircleLine.pipelineState",
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
            throw RenderError.invalidFrame(reason: "CircleLine requires at least 2 magnitudes.")
        }
        let layers = frame.style.effectiveLayers

        bufferPool.advance()

        let magnitudeByteCount = MemoryLayout<Float>.stride * frame.magnitudes.count
        let magnitudeBuffer = try bufferPool.buffer(
            forKey: "CircleLine.magnitudes",
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
                forKey: "CircleLine.stops.\(layerIndex)",
                byteCount: stopByteCount
            )
            _ = stops.withUnsafeBufferPointer { ptr in
                memcpy(stopBuffer.contents(), ptr.baseAddress, stopByteCount)
            }

            var uniforms = CircleLineUniforms(
                viewportSize: viewportSize,
                time: Float(frame.timestamp),
                baseRadius: Float(frame.style.circleBaseRadius + layer.radialOffset),
                maxHeight: Float(frame.style.maxHeight),
                startAngle: Float(layer.range.lowerBound),
                endAngle: Float(layer.range.upperBound),
                softness: frame.style.softness,
                phase: layer.gradient.dynamicPhase
                    ? Float(frame.timestamp) * layer.gradient.phaseSpeed
                    : 0,
                bandCount: Int32(frame.magnitudes.count),
                stopCount: Int32(stops.count),
                dynamicPhase: layer.gradient.dynamicPhase ? 1 : 0,
                layerThickness: Float(layer.thickness)
            )

            encoder.setVertexBytes(&uniforms, length: MemoryLayout<CircleLineUniforms>.stride, index: 1)
            encoder.setFragmentBuffer(stopBuffer, offset: 0, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CircleLineUniforms>.stride, index: 1)
            encoder.drawPrimitives(
                type: .triangleStrip,
                vertexStart: 0,
                vertexCount: vertexCount
            )
        }
    }
}
