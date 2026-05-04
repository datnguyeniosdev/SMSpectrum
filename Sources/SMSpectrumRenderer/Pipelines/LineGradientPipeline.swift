import Foundation
import Metal
import simd

/// Renders the spectrum as a filled area beneath the magnitude curve.
/// Iterates `effectiveLayers` so each layer fills its own horizontal slice
/// with its own gradient and curve top.
final class LineGradientPipeline: SpectrumPipeline {

    private let pipelineState: MTLRenderPipelineState

    init(library: PipelineLibrary, pixelFormat: MTLPixelFormat) throws {
        let vertex = try library.makeFunction(named: "lineGradientVertex")
        let fragment = try library.makeFunction(named: "lineGradientFragment")

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "SMSpectrum.LineGradient"
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
            throw RenderError.pipelineCreationFailed(stage: "LineGradient.pipelineState", underlying: error)
        }
    }

    func encode(
        frame: RenderFrame,
        viewportSize: SIMD2<Float>,
        bufferPool: BufferPool,
        encoder: MTLRenderCommandEncoder
    ) throws {
        guard frame.magnitudes.count >= 2 else {
            throw RenderError.invalidFrame(reason: "LineGradient requires at least 2 magnitudes.")
        }
        let layers = frame.style.effectiveLayers

        bufferPool.advance()

        let magnitudeByteCount = MemoryLayout<Float>.stride * frame.magnitudes.count
        let magnitudeBuffer = try bufferPool.buffer(forKey: "LineGradient.magnitudes", byteCount: magnitudeByteCount)
        _ = frame.magnitudes.withUnsafeBufferPointer { ptr in
            memcpy(magnitudeBuffer.contents(), ptr.baseAddress, magnitudeByteCount)
        }

        let totalSamples = frame.magnitudes.count * tessellationFactor
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(magnitudeBuffer, offset: 0, index: 0)

        for (layerIndex, layer) in layers.enumerated() {
            let stops = layer.gradient.stops
            let stopByteCount = MemoryLayout<SIMD4<Float>>.stride * stops.count
            let stopBuffer = try bufferPool.buffer(
                forKey: "LineGradient.stops.\(layerIndex)",
                byteCount: stopByteCount
            )
            _ = stops.withUnsafeBufferPointer { ptr in
                memcpy(stopBuffer.contents(), ptr.baseAddress, stopByteCount)
            }

            var uniforms = SpectrumUniforms(
                viewportSize: viewportSize,
                time: Float(frame.timestamp),
                maxHeight: Float(frame.style.maxHeight),
                thickness: Float(frame.style.thickness),
                softness: frame.style.softness,
                phase: layer.gradient.dynamicPhase
                    ? Float(frame.timestamp) * layer.gradient.phaseSpeed
                    : 0,
                barSpacing: frame.style.barSpacing,
                sideMode: SpectrumUniforms.sideModeRaw(frame.style.sideMode),
                bandCount: Int32(frame.magnitudes.count),
                stopCount: Int32(stops.count),
                dynamicPhase: layer.gradient.dynamicPhase ? 1 : 0,
                rangeStart: Float(layer.range.lowerBound),
                rangeEnd: Float(layer.range.upperBound),
                layerThickness: Float(layer.thickness)
            )

            encoder.setVertexBytes(&uniforms, length: MemoryLayout<SpectrumUniforms>.stride, index: 1)
            encoder.setFragmentBuffer(stopBuffer, offset: 0, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SpectrumUniforms>.stride, index: 1)
            encoder.drawPrimitives(
                type: .triangleStrip,
                vertexStart: 0,
                vertexCount: totalSamples * 2
            )
        }
    }
}
