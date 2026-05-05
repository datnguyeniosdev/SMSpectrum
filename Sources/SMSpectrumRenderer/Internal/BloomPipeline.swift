import Foundation
import Metal
import simd

private struct BrightPassUniforms {
    var threshold: Float
}

private struct BlurUniforms {
    var direction: SIMD2<Float>
}

private struct CompositeUniforms {
    var intensity: Float
}

/// Two-pass separable gaussian bloom + additive composite.
///
/// Owns three offscreen textures: a full-resolution `scene` target the spectrum
/// renders into, plus two half-resolution ping-pong textures used for the
/// bright-pass and blur. Textures are reallocated when the viewport size
/// changes.
final class BloomPipeline {

    let device: MTLDevice

    private let brightPipeline: MTLRenderPipelineState
    private let blurPipeline: MTLRenderPipelineState
    private let compositePipeline: MTLRenderPipelineState

    private let pixelFormat: MTLPixelFormat
    private let downsampleFactor: Int = 2

    private var sceneTexture: MTLTexture?
    private var bloomA: MTLTexture?
    private var bloomB: MTLTexture?
    private var lastSize: (width: Int, height: Int) = (0, 0)

    init(library: PipelineLibrary, pixelFormat: MTLPixelFormat) throws {
        self.device = library.device
        self.pixelFormat = pixelFormat

        let vertex = try library.makeFunction(named: "bloomFullscreenVertex")
        let brightFragment = try library.makeFunction(named: "bloomBrightFragment")
        let blurFragment = try library.makeFunction(named: "bloomBlurFragment")
        let compositeFragment = try library.makeFunction(named: "bloomCompositeFragment")

        func make(label: String, fragment: MTLFunction) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = label
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = pixelFormat
            descriptor.colorAttachments[0].isBlendingEnabled = false
            do {
                return try library.device.makeRenderPipelineState(descriptor: descriptor)
            } catch {
                throw RenderError.pipelineCreationFailed(stage: label, underlying: error)
            }
        }

        self.brightPipeline = try make(label: "Bloom.bright", fragment: brightFragment)
        self.blurPipeline = try make(label: "Bloom.blur", fragment: blurFragment)
        self.compositePipeline = try make(label: "Bloom.composite", fragment: compositeFragment)
    }

    /// Returns the scene texture sized for the current viewport, allocating or
    /// resizing as needed. Caller renders the spectrum into this texture
    /// before invoking `apply`.
    func sceneTexture(for size: (width: Int, height: Int)) throws -> MTLTexture {
        try ensureTextures(size: size)
        guard let scene = sceneTexture else {
            throw RenderError.invalidFrame(reason: "Bloom scene texture allocation failed.")
        }
        return scene
    }

    /// Brightness-thresholds + blurs the scene texture, then composites the
    /// result into the supplied drawable pass descriptor.
    func apply(
        commandBuffer: MTLCommandBuffer,
        filter: RenderBloomFilter,
        drawableTexture: MTLTexture
    ) throws {
        guard let scene = sceneTexture, let a = bloomA, let b = bloomB else {
            throw RenderError.invalidFrame(reason: "Bloom textures not allocated.")
        }

        try runBrightPass(
            commandBuffer: commandBuffer,
            source: scene,
            target: a,
            threshold: filter.threshold
        )

        let texW = Float(a.width)
        let texH = Float(a.height)
        try runBlurPass(
            commandBuffer: commandBuffer,
            source: a,
            target: b,
            direction: SIMD2<Float>(filter.radius / texW, 0)
        )
        try runBlurPass(
            commandBuffer: commandBuffer,
            source: b,
            target: a,
            direction: SIMD2<Float>(0, filter.radius / texH)
        )

        try runComposite(
            commandBuffer: commandBuffer,
            scene: scene,
            bloom: a,
            intensity: filter.intensity,
            target: drawableTexture
        )
    }

    // MARK: - Private

    private func ensureTextures(size: (width: Int, height: Int)) throws {
        guard size.width > 0, size.height > 0 else {
            throw RenderError.invalidFrame(reason: "Bloom requires a non-zero viewport.")
        }
        if size == lastSize, sceneTexture != nil { return }

        let sceneDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: size.width,
            height: size.height,
            mipmapped: false
        )
        sceneDescriptor.usage = [.renderTarget, .shaderRead]
        sceneDescriptor.storageMode = .private
        guard let scene = device.makeTexture(descriptor: sceneDescriptor) else {
            throw RenderError.invalidFrame(reason: "Failed to allocate bloom scene texture.")
        }
        scene.label = "Bloom.scene"

        let halfW = max(1, size.width / downsampleFactor)
        let halfH = max(1, size.height / downsampleFactor)
        let bloomDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: halfW,
            height: halfH,
            mipmapped: false
        )
        bloomDescriptor.usage = [.renderTarget, .shaderRead]
        bloomDescriptor.storageMode = .private
        guard
            let a = device.makeTexture(descriptor: bloomDescriptor),
            let b = device.makeTexture(descriptor: bloomDescriptor)
        else {
            throw RenderError.invalidFrame(reason: "Failed to allocate bloom blur textures.")
        }
        a.label = "Bloom.A"
        b.label = "Bloom.B"

        sceneTexture = scene
        bloomA = a
        bloomB = b
        lastSize = size
    }

    private func makeOffscreenPass(target: MTLTexture) -> MTLRenderPassDescriptor {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        return pass
    }

    private func runBrightPass(
        commandBuffer: MTLCommandBuffer,
        source: MTLTexture,
        target: MTLTexture,
        threshold: Float
    ) throws {
        let pass = makeOffscreenPass(target: target)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            throw RenderError.invalidFrame(reason: "Failed to create bloom bright encoder.")
        }
        encoder.label = "Bloom.bright"
        encoder.setRenderPipelineState(brightPipeline)
        encoder.setFragmentTexture(source, index: 0)
        var u = BrightPassUniforms(threshold: threshold)
        encoder.setFragmentBytes(&u, length: MemoryLayout<BrightPassUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    private func runBlurPass(
        commandBuffer: MTLCommandBuffer,
        source: MTLTexture,
        target: MTLTexture,
        direction: SIMD2<Float>
    ) throws {
        let pass = makeOffscreenPass(target: target)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            throw RenderError.invalidFrame(reason: "Failed to create bloom blur encoder.")
        }
        encoder.label = "Bloom.blur"
        encoder.setRenderPipelineState(blurPipeline)
        encoder.setFragmentTexture(source, index: 0)
        var u = BlurUniforms(direction: direction)
        encoder.setFragmentBytes(&u, length: MemoryLayout<BlurUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    private func runComposite(
        commandBuffer: MTLCommandBuffer,
        scene: MTLTexture,
        bloom: MTLTexture,
        intensity: Float,
        target: MTLTexture
    ) throws {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            throw RenderError.invalidFrame(reason: "Failed to create bloom composite encoder.")
        }
        encoder.label = "Bloom.composite"
        encoder.setRenderPipelineState(compositePipeline)
        encoder.setFragmentTexture(scene, index: 0)
        encoder.setFragmentTexture(bloom, index: 1)
        var u = CompositeUniforms(intensity: intensity)
        encoder.setFragmentBytes(&u, length: MemoryLayout<CompositeUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }
}
