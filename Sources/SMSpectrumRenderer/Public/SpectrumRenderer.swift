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
    private var lineGradientPipeline: LineGradientPipeline

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
        self.lineGradientPipeline = try LineGradientPipeline(library: library, pixelFormat: colorPixelFormat)
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

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            frameSemaphore.signal()
            throw RenderError.invalidFrame(reason: "Failed to create command buffer.")
        }
        commandBuffer.label = "SpectrumRenderer.frame"

        let semaphore = frameSemaphore
        commandBuffer.addCompletedHandler { _ in
            semaphore.signal()
        }

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            frameSemaphore.signal()
            throw RenderError.invalidFrame(reason: "Failed to create render encoder.")
        }
        encoder.label = "SpectrumRenderer.encoder"

        switch frame.style.style {
        case .digitalBars:
            try digitalPipeline.encode(
                frame: frame,
                viewportSize: viewportSize,
                bufferPool: bufferPool,
                encoder: encoder
            )
        case .analogLines:
            try analogLinePipeline.encode(
                frame: frame,
                viewportSize: viewportSize,
                bufferPool: bufferPool,
                encoder: encoder
            )
        case .analogDots:
            try analogDotPipeline.encode(
                frame: frame,
                viewportSize: viewportSize,
                bufferPool: bufferPool,
                encoder: encoder
            )
        case .circleBars:
            try circleBarPipeline.encode(
                frame: frame,
                viewportSize: viewportSize,
                bufferPool: bufferPool,
                encoder: encoder
            )
        case .circleHermite:
            try circleHermitePipeline.encode(
                frame: frame,
                viewportSize: viewportSize,
                bufferPool: bufferPool,
                encoder: encoder
            )
        case .lineGradient:
            try lineGradientPipeline.encode(
                frame: frame,
                viewportSize: viewportSize,
                bufferPool: bufferPool,
                encoder: encoder
            )
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
