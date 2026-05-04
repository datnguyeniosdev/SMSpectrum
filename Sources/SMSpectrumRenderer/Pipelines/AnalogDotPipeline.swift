import Foundation
import Metal
import simd

/// Renders each band as a circular dot via instanced quads with an SDF circle
/// fragment shader. Iterates `effectiveLayers` so each layer can occupy its
/// own slice with its own gradient and dot radius (`layerThickness`).
final class AnalogDotPipeline: SpectrumPipeline {

    private let pipelineState: MTLRenderPipelineState

    init(library: PipelineLibrary, pixelFormat: MTLPixelFormat) throws {
        let vertex = try library.makeFunction(named: "analogDotVertex")
        let fragment = try library.makeFunction(named: "analogDotFragment")

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "SMSpectrum.AnalogDot"
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            self.pipelineState = try library.device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw RenderError.pipelineCreationFailed(stage: "AnalogDot.pipelineState", underlying: error)
        }
    }

    func encode(
        frame: RenderFrame,
        viewportSize: SIMD2<Float>,
        bufferPool: BufferPool,
        encoder: MTLRenderCommandEncoder
    ) throws {
        guard !frame.magnitudes.isEmpty else {
            throw RenderError.invalidFrame(reason: "AnalogDot requires non-empty magnitudes.")
        }
        let layers = frame.style.effectiveLayers

        bufferPool.advance()

        let magnitudeByteCount = MemoryLayout<Float>.stride * frame.magnitudes.count
        let magnitudeBuffer = try bufferPool.buffer(forKey: "AnalogDot.magnitudes", byteCount: magnitudeByteCount)
        _ = frame.magnitudes.withUnsafeBufferPointer { ptr in
            memcpy(magnitudeBuffer.contents(), ptr.baseAddress, magnitudeByteCount)
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(magnitudeBuffer, offset: 0, index: 0)

        for (layerIndex, layer) in layers.enumerated() {
            let stops = layer.gradient.stops
            let stopByteCount = MemoryLayout<SIMD4<Float>>.stride * stops.count
            let stopBuffer = try bufferPool.buffer(
                forKey: "AnalogDot.stops.\(layerIndex)",
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
                vertexCount: 4,
                instanceCount: frame.magnitudes.count
            )
        }
    }
}
