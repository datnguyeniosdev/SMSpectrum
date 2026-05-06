import Foundation
import Metal
import MetalKit
import QuartzCore

/// Top-level Metal renderer that draws `RenderFrame` instances into a target
/// `CAMetalLayer` or `MTKView`.
///
/// The renderer is fully decoupled from audio: it receives pre-computed frames
/// and dispatches them to the appropriate pipeline based on `RenderStyle`.
/// This boundary is what allows the v2 video exporter to reuse the same
/// renderer with a different render target.
///
/// When `RenderFrame.style.bloomFilter` is non-nil, the spectrum is rendered
/// into an offscreen texture and a separable gaussian bloom is composited
/// into the drawable.
public final class SpectrumRenderer {

    // MARK: - Public

    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue

    /// Pixel format of the render target. Default `.bgra8Unorm`.
    public var colorPixelFormat: MTLPixelFormat = .bgra8Unorm

    /// Triple-buffered max in-flight frames.
    public static let maxInFlightFrames: Int = 3

    // MARK: - Private

    private let pipelineLibrary: PipelineLibrary
    private let bufferPool: BufferPool
    private let frameSemaphore = DispatchSemaphore(value: SpectrumRenderer.maxInFlightFrames)

    private var digitalPipeline: DigitalBarPipeline
    private var analogLinePipeline: AnalogLinePipeline
    private var analogDotPipeline: AnalogDotPipeline
    private var circleBarPipeline: CircleBarPipeline
    private var circleHermitePipeline: CircleHermitePipeline
    private var circleLinePipeline: CircleLinePipeline
    private var lineGradientPipeline: LineGradientPipeline
    private var bloomPipeline: BloomPipeline

    // MARK: - Init

    public convenience init() throws {
        let device = try MetalDeviceProvider.makeSystemDefaultDevice()
        try self.init(device: device)
    }

    public init(device: MTLDevice) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            throw RenderError.metalDeviceUnavailable
        }
        self.commandQueue = queue

        let library = try PipelineLibrary(device: device)
        self.pipelineLibrary = library
        self.bufferPool = BufferPool(device: device, capacity: SpectrumRenderer.maxInFlightFrames)

        self.digitalPipeline = try DigitalBarPipeline(library: library, pixelFormat: colorPixelFormat)
        self.analogLinePipeline = try AnalogLinePipeline(library: library, pixelFormat: colorPixelFormat)
        self.analogDotPipeline = try AnalogDotPipeline(library: library, pixelFormat: colorPixelFormat)
        self.circleBarPipeline = try CircleBarPipeline(library: library, pixelFormat: colorPixelFormat)
        self.circleHermitePipeline = try CircleHermitePipeline(library: library, pixelFormat: colorPixelFormat)
        self.circleLinePipeline = try CircleLinePipeline(library: library, pixelFormat: colorPixelFormat)
        self.lineGradientPipeline = try LineGradientPipeline(library: library, pixelFormat: colorPixelFormat)
        self.bloomPipeline = try BloomPipeline(library: library, pixelFormat: colorPixelFormat)
    }

    // MARK: - Drawing

    /// Configures an `MTKView` with this renderer's pixel format and recommended settings.
    public func attach(to view: MTKView) {
        view.device = device
        view.colorPixelFormat = colorPixelFormat
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 60
        view.isPaused = false
        view.enableSetNeedsDisplay = false
    }

    /// Renders a frame into the provided drawable + render pass descriptor.
    ///
    /// - Note: Caller is responsible for obtaining a current drawable from the
    ///   target view/layer and passing the matching render pass descriptor.
    public func render(
        frame: RenderFrame,
        drawable: CAMetalDrawable,
        renderPassDescriptor: MTLRenderPassDescriptor,
        viewportSize: SIMD2<Float>
    ) throws {
        frameSemaphore.wait()

        var didCommit = false
        defer {
            if !didCommit { frameSemaphore.signal() }
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw RenderError.invalidFrame(reason: "Failed to create command buffer.")
        }
        commandBuffer.label = "SpectrumRenderer.frame"

        let semaphore = frameSemaphore
        commandBuffer.addCompletedHandler { _ in
            semaphore.signal()
        }

        if let bloomFilter = frame.style.bloomFilter {
            try renderWithBloom(
                frame: frame,
                bloomFilter: bloomFilter,
                drawable: drawable,
                viewportSize: viewportSize,
                clearColor: renderPassDescriptor.colorAttachments[0].clearColor,
                commandBuffer: commandBuffer
            )
        } else {
            try renderDirect(
                frame: frame,
                viewportSize: viewportSize,
                renderPassDescriptor: renderPassDescriptor,
                commandBuffer: commandBuffer
            )
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
        didCommit = true
    }

    // MARK: - Render paths

    private func renderDirect(
        frame: RenderFrame,
        viewportSize: SIMD2<Float>,
        renderPassDescriptor: MTLRenderPassDescriptor,
        commandBuffer: MTLCommandBuffer
    ) throws {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            throw RenderError.invalidFrame(reason: "Failed to create render encoder.")
        }
        encoder.label = "SpectrumRenderer.encoder"
        try dispatch(frame: frame, viewportSize: viewportSize, encoder: encoder)
        encoder.endEncoding()
    }

    private func renderWithBloom(
        frame: RenderFrame,
        bloomFilter: RenderBloomFilter,
        drawable: CAMetalDrawable,
        viewportSize: SIMD2<Float>,
        clearColor: MTLClearColor,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let width = max(1, Int(viewportSize.x))
        let height = max(1, Int(viewportSize.y))
        let scene = try bloomPipeline.sceneTexture(for: (width, height))

        let scenePass = MTLRenderPassDescriptor()
        scenePass.colorAttachments[0].texture = scene
        scenePass.colorAttachments[0].loadAction = .clear
        scenePass.colorAttachments[0].storeAction = .store
        scenePass.colorAttachments[0].clearColor = clearColor

        guard let sceneEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: scenePass) else {
            throw RenderError.invalidFrame(reason: "Failed to create scene encoder.")
        }
        sceneEncoder.label = "Spectrum.scene"
        try dispatch(frame: frame, viewportSize: viewportSize, encoder: sceneEncoder)
        sceneEncoder.endEncoding()

        try bloomPipeline.apply(
            commandBuffer: commandBuffer,
            filter: bloomFilter,
            drawableTexture: drawable.texture
        )
    }

    private func dispatch(
        frame: RenderFrame,
        viewportSize: SIMD2<Float>,
        encoder: MTLRenderCommandEncoder
    ) throws {
        switch frame.style.style {
        case .digitalBars:
            try digitalPipeline.encode(
                frame: frame, viewportSize: viewportSize,
                bufferPool: bufferPool, encoder: encoder
            )
        case .analogLines:
            try analogLinePipeline.encode(
                frame: frame, viewportSize: viewportSize,
                bufferPool: bufferPool, encoder: encoder
            )
        case .analogDots:
            try analogDotPipeline.encode(
                frame: frame, viewportSize: viewportSize,
                bufferPool: bufferPool, encoder: encoder
            )
        case .circleBars:
            try circleBarPipeline.encode(
                frame: frame, viewportSize: viewportSize,
                bufferPool: bufferPool, encoder: encoder
            )
        case .circleHermite:
            try circleHermitePipeline.encode(
                frame: frame, viewportSize: viewportSize,
                bufferPool: bufferPool, encoder: encoder
            )
        case .lineGradient:
            try lineGradientPipeline.encode(
                frame: frame, viewportSize: viewportSize,
                bufferPool: bufferPool, encoder: encoder
            )
        case .circleLine:
            try circleLinePipeline.encode(
                frame: frame, viewportSize: viewportSize,
                bufferPool: bufferPool, encoder: encoder
            )
        }
    }
}
