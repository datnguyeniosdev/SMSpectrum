import Foundation
import MetalKit
import QuartzCore
import SMSpectrumRenderer

#if canImport(UIKit)
import UIKit
#endif

/// The visualization view — display only.
///
/// `SMSpectrumView` consumes pre-computed magnitudes (one value per band,
/// 0...1) and renders them using the configured `SMStyle`. It does NOT
/// capture audio or run FFT — that responsibility belongs to
/// `SMAudioSpectrumDriver` (or whatever DSP source you choose to implement).
///
/// ## Driving the view
///
/// **Custom data** (network feed, simulation, your own DSP):
/// ```swift
/// let view = try SMSpectrumView(configuration: .digital)
/// // ...later, per frame:
/// view.push(magnitudes: myMagnitudes)
/// ```
///
/// **Live audio** (microphone, file, external `AVAudioEngine`):
/// ```swift
/// let view = try SMSpectrumView(configuration: .digital)
/// let driver = SMAudioSpectrumDriver(configuration: .digital)
/// driver.attach(to: view)
/// try driver.start(source: .microphone)
/// ```
public final class SMSpectrumView: MTKView {

    // MARK: - Public

    public weak var spectrumDelegate: SMSpectrumViewDelegate?

    public var configuration: SMConfiguration {
        didSet { applyConfiguration() }
    }

    /// Song playback progress, 0…1. Drives a thin inner ring timeline
    /// that fills clockwise inside the circle. Set to nil to hide.
    public var timelineProgress: CGFloat? {
        didSet { updateTimelineRing() }
    }

    /// Color of the inner timeline ring. Default white at 60 % opacity.
    public var timelineColor: CGColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.6) {
        didSet { timelineLayer.strokeColor = timelineColor }
    }

    // MARK: - Internal services

    private let renderer: SpectrumRenderer
    private let frameBuilder: RenderFrameBuilder
    private let pushQueue = DispatchQueue(label: "com.darrennguyen.smspectrum.push", qos: .userInteractive)

    private var latestFrame: RenderFrame?
    private let frameLock = NSLock()

    // MARK: - Timeline ring

    private let timelineLayer = CAShapeLayer()

    // MARK: - Init

    public init(
        frame: CGRect = .zero,
        configuration: SMConfiguration = .digital
    ) throws {
        self.configuration = configuration

        do {
            self.renderer = try SpectrumRenderer()
        } catch {
            throw SMError.rendererInitializationFailed(underlying: error)
        }

        self.frameBuilder = RenderFrameBuilder(configuration: configuration)

        super.init(frame: frame, device: renderer.device)
        renderer.attach(to: self)
        delegate = self
        setupTimelineLayer()
    }

    @available(*, unavailable)
    public required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported.")
    }

    // MARK: - Timeline

    private func setupTimelineLayer() {
        timelineLayer.fillColor = nil
        timelineLayer.strokeColor = timelineColor
        timelineLayer.lineWidth = 2.5
        timelineLayer.lineCap = .round
        timelineLayer.strokeEnd = 0
        #if canImport(UIKit)
        layer.addSublayer(timelineLayer)
        #else
        layer?.addSublayer(timelineLayer)
        #endif
        updateTimelineRing()
    }

    private func updateTimelineRing() {
        let size = min(bounds.width, bounds.height)
        let radius = size * 0.27
        let path = CGMutablePath()
        path.addArc(
            center: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        timelineLayer.path = path
        timelineLayer.strokeEnd = timelineProgress ?? 0
    }

    // MARK: - Push API

    /// Pushes a single frame of band magnitudes for display. Magnitudes
    /// should be 0...1 per band; lengths matching `configuration.bandCount`
    /// render directly, mismatched lengths are treated as raw FFT half-bins
    /// and remapped via the configuration's log-band layout.
    ///
    /// Smoothing (`SMConfiguration.smoothing` and `bandSmoothing`) is
    /// applied internally before rendering.
    ///
    /// Safe to call from any thread.
    public func push(
        magnitudes: [Float],
        timestamp: TimeInterval = CACurrentMediaTime()
    ) {
        push(frame: SMSpectrumFrame(magnitudes: magnitudes, timestamp: timestamp))
    }

    /// Pushes a fully-formed frame for display. `bandFrequencies` is
    /// forwarded to the delegate; if empty, the view computes default Hz
    /// values from the configuration.
    ///
    /// Safe to call from any thread.
    public func push(frame incoming: SMSpectrumFrame) {
        pushQueue.async { [weak self] in
            self?.handle(incoming: incoming)
        }
    }

    // MARK: - Plumbing

    private func handle(incoming: SMSpectrumFrame) {
        let smoothed = frameBuilder.applySmoothing(magnitudes: incoming.magnitudes)
        let frequencies = incoming.bandFrequencies.isEmpty
            ? frameBuilder.bandCenterFrequencies(sampleRate: 44_100)
            : incoming.bandFrequencies

        let publicFrame = SMSpectrumFrame(
            magnitudes: smoothed,
            timestamp: incoming.timestamp,
            bandFrequencies: frequencies
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.spectrumDelegate?.spectrumView(self, didProduce: publicFrame)
            let bass = self.computeBassEnergy(smoothed)
            self.spectrumDelegate?.spectrumView(self, didUpdateBassLevel: bass)
            let (b, m, t) = self.computeSpectrumBands(smoothed)
            self.spectrumDelegate?.spectrumView(self, didUpdateSpectrum: b, mid: m, treble: t)
        }

        let renderFrame = frameBuilder.makeRenderFrame(
            magnitudes: smoothed,
            timestamp: incoming.timestamp
        )
        frameLock.lock()
        latestFrame = renderFrame
        frameLock.unlock()
    }

    private func applyConfiguration() {
        frameBuilder.configuration = configuration
    }

    /// Bass energy from the lowest 20 % of bands, averaged.
    private func computeBassEnergy(_ magnitudes: [Float]) -> Float {
        guard !magnitudes.isEmpty else { return 0 }
        let bassCount = max(1, magnitudes.count / 5)
        let bassSlice = magnitudes.prefix(bassCount)
        return bassSlice.reduce(0, +) / Float(bassSlice.count)
    }

    /// Splits magnitudes into bass (0–15 %), mid (15–50 %), treble (50–100 %).
    private func computeSpectrumBands(_ magnitudes: [Float]) -> (Float, Float, Float) {
        guard !magnitudes.isEmpty else { return (0, 0, 0) }
        let n = magnitudes.count
        let bassEnd = max(1, n * 15 / 100)
        let midEnd  = max(bassEnd + 1, n * 50 / 100)
        return (
            magnitudes[0..<bassEnd].reduce(0, +) / Float(bassEnd),
            magnitudes[bassEnd..<midEnd].reduce(0, +) / Float(midEnd - bassEnd),
            magnitudes[midEnd..<n].reduce(0, +) / Float(n - midEnd)
        )
    }

    func notifyError(_ error: SMError) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.spectrumDelegate?.spectrumView(self, didFailWith: error)
        }
    }
}

// MARK: - MTKViewDelegate

extension SMSpectrumView: MTKViewDelegate {

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateTimelineRing()
    }

    public func draw(in view: MTKView) {
        frameLock.lock()
        let frame = latestFrame
        frameLock.unlock()

        guard let frame,
              let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else {
            return
        }

        updateTimelineRing()

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
