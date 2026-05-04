import Foundation
import AVFoundation
import MetalKit
import SMSpectrumRenderer

#if canImport(UIKit)
import UIKit
#endif

/// The primary visualization view.
///
/// Combines an `AudioEngine` (PCM ingest), an `FFTProcessor` (DSP), a
/// `RenderFrameBuilder` (per-style frame composition), and a `SpectrumRenderer`
/// (Metal draw). Acts as an `MTKViewDelegate` to drive frames at display rate.
public final class SMSpectrumView: MTKView {

    // MARK: - Public

    public weak var spectrumDelegate: SMSpectrumViewDelegate?

    public var configuration: SMConfiguration {
        didSet { applyConfiguration() }
    }

    public var source: SMSource {
        didSet { reloadSource() }
    }

    public private(set) var isRunning: Bool = false

    // MARK: - Internal services

    private let renderer: SpectrumRenderer
    private let audioEngine: AudioEngine
    private let fftProcessor: FFTProcessor
    private let frameBuilder: RenderFrameBuilder
    private let renderQueue = DispatchQueue(label: "com.darrennguyen.smspectrum.render", qos: .userInteractive)

    private var latestFrame: RenderFrame?
    private let frameLock = NSLock()

    // MARK: - Init

    public init(
        frame: CGRect = .zero,
        configuration: SMConfiguration = .digital,
        source: SMSource = .microphone
    ) throws {
        self.configuration = configuration
        self.source = source

        do {
            self.renderer = try SpectrumRenderer()
        } catch {
            throw SMError.rendererInitializationFailed(underlying: error)
        }

        self.audioEngine = AudioEngine()
        self.fftProcessor = FFTProcessor(fftSize: configuration.fftSize)
        self.frameBuilder = RenderFrameBuilder(configuration: configuration)

        super.init(frame: frame, device: renderer.device)

        renderer.attach(to: self)
        delegate = self

        audioEngine.onPCMBuffer = { [weak self] buffer, sampleRate, time in
            self?.handlePCMBuffer(buffer, sampleRate: sampleRate, time: time)
        }
        audioEngine.onError = { [weak self] error in
            self?.notifyError(error)
        }
    }

    @available(*, unavailable)
    public required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported.")
    }

    // MARK: - Lifecycle

    public func start() {
        guard !isRunning else { return }
        do {
            try audioEngine.start(source: source)
            isRunning = true
        } catch let error as SMError {
            notifyError(error)
        } catch {
            notifyError(.audioEngineFailedToStart(underlying: error))
        }
    }

    public func pause() {
        audioEngine.pause()
        isRunning = false
    }

    public func stop() {
        audioEngine.stop()
        isRunning = false
    }

    /// Manually push a PCM buffer when `source == .manual`.
    public func push(buffer: AVAudioPCMBuffer, sampleRate: Double, time: TimeInterval) {
        handlePCMBuffer(buffer, sampleRate: sampleRate, time: time)
    }

    // MARK: - Plumbing

    private func applyConfiguration() {
        fftProcessor.fftSize = configuration.fftSize
        frameBuilder.configuration = configuration
    }

    private func reloadSource() {
        let wasRunning = isRunning
        stop()
        if wasRunning { start() }
    }

    private func handlePCMBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double, time: TimeInterval) {
        let magnitudes = fftProcessor.process(buffer: buffer, sampleRate: sampleRate)
        let smoothed = frameBuilder.applySmoothing(magnitudes: magnitudes)
        let bandFrequencies = frameBuilder.bandCenterFrequencies(sampleRate: Float(sampleRate))

        let publicFrame = SMSpectrumFrame(
            magnitudes: smoothed,
            timestamp: time,
            bandFrequencies: bandFrequencies
        )
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spectrumDelegate?.spectrumView(self, didProduce: publicFrame)
        }

        let renderFrame = frameBuilder.makeRenderFrame(magnitudes: smoothed, timestamp: time)
        frameLock.lock()
        latestFrame = renderFrame
        frameLock.unlock()
    }

    private func notifyError(_ error: SMError) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spectrumDelegate?.spectrumView(self, didFailWith: error)
        }
    }
}

extension SMSpectrumView: MTKViewDelegate {

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No-op; pipelines read viewport per draw.
    }

    public func draw(in view: MTKView) {
        frameLock.lock()
        let frame = latestFrame
        frameLock.unlock()

        guard let frame = frame,
              let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else {
            return
        }

        let viewport = SIMD2<Float>(
            Float(view.drawableSize.width),
            Float(view.drawableSize.height)
        )

        do {
            try renderer.render(
                frame: frame,
                drawable: drawable,
                renderPassDescriptor: descriptor,
                viewportSize: viewport
            )
        } catch {
            notifyError(.renderFailed(underlying: error))
        }
    }
}
