import Foundation
import AVFoundation

/// Captures audio (microphone, file playback, external `AVAudioEngine`, or
/// manual PCM push) and produces `SMSpectrumFrame` values by running the
/// PCM through FFT + log-band mapping.
///
/// This is the optional audio adapter — `SMSpectrumView` only renders, it
/// does not own audio. Use this driver when you want SMSpectrum's built-in
/// audio pipeline; skip it entirely if you have your own frequency data.
///
/// ## Wire-up
///
/// ```swift
/// let view   = try SMSpectrumView(configuration: .digital)
/// let driver = SMAudioSpectrumDriver(configuration: .digital)
/// driver.attach(to: view)
/// driver.onError = { error in print("audio error:", error) }
///
/// try driver.start(source: .microphone)
/// // ...later:
/// driver.stop()
/// ```
///
/// ## Custom data path (no driver)
///
/// ```swift
/// let view = try SMSpectrumView(configuration: .digital)
/// // Compute Hz layout up front so you know which slot is which:
/// let frequencies = view.configuration.bandCenterFrequencies(sampleRate: 48_000)
/// // ... later:
/// view.push(magnitudes: yourMagnitudes)
/// ```
public final class SMAudioSpectrumDriver {

    // MARK: - Public

    public var configuration: SMConfiguration {
        didSet { applyConfiguration() }
    }

    /// Called whenever a new frame is produced. Delivered on a background
    /// thread — dispatch to main yourself if your handler touches UI.
    public var onFrame: ((SMSpectrumFrame) -> Void)?

    /// Called on the main thread when the audio engine reports an error.
    public var onError: ((SMError) -> Void)?

    public private(set) var isRunning: Bool = false
    public private(set) var currentSource: SMSource?

    // MARK: - Internal services

    private let audioEngine: AudioEngine
    private let fftProcessor: FFTProcessor
    private var bandMapper: BandMapper

    // MARK: - Init

    public init(configuration: SMConfiguration) {
        self.configuration = configuration
        self.audioEngine = AudioEngine()
        self.fftProcessor = FFTProcessor(fftSize: configuration.fftSize)
        self.bandMapper = BandMapper(
            bandCount: configuration.bandCount,
            frequencyRange: configuration.frequencyRange
        )

        audioEngine.onPCMBuffer = { [weak self] buffer, sampleRate, time in
            self?.handle(buffer: buffer, sampleRate: sampleRate, time: time)
        }
        audioEngine.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.onError?(error)
            }
        }
    }

    // MARK: - Lifecycle

    public func start(source: SMSource) throws {
        guard !isRunning else { return }
        do {
            try audioEngine.start(source: source)
            isRunning = true
            currentSource = source
        } catch let error as SMError {
            throw error
        } catch {
            throw SMError.audioEngineFailedToStart(underlying: error)
        }
    }

    public func pause() {
        audioEngine.pause()
        isRunning = false
    }

    public func stop() {
        audioEngine.stop()
        isRunning = false
        currentSource = nil
    }

    // MARK: - Manual push

    /// Manually push a PCM buffer (use when starting with `.manual` source,
    /// or when bridging from a non-`AVAudioEngine` audio path).
    public func push(
        pcmBuffer: AVAudioPCMBuffer,
        sampleRate: Double,
        time: TimeInterval
    ) {
        handle(buffer: pcmBuffer, sampleRate: sampleRate, time: time)
    }

    // MARK: - View binding

    /// Convenience: wires `onFrame` to forward every produced frame to the
    /// given view via `view.push(frame:)`. Replaces any prior `onFrame`.
    /// Errors are forwarded to the view's delegate (in addition to firing
    /// this driver's `onError`).
    public func attach(to view: SMSpectrumView) {
        onFrame = { [weak view] frame in
            view?.push(frame: frame)
        }
        let prior = onError
        onError = { [weak view] error in
            prior?(error)
            view?.notifyError(error)
        }
    }

    // MARK: - Pipeline

    private func handle(buffer: AVAudioPCMBuffer, sampleRate: Double, time: TimeInterval) {
        let rawMagnitudes = fftProcessor.process(buffer: buffer, sampleRate: sampleRate)
        let banded = bandMapper.mapToBands(
            magnitudes: rawMagnitudes,
            sampleRate: Float(sampleRate),
            fftSize: configuration.fftSize.rawValue
        )
        let frequencies = bandMapper.bandCenterFrequencies(sampleRate: Float(sampleRate))
        let frame = SMSpectrumFrame(
            magnitudes: banded,
            timestamp: time,
            bandFrequencies: frequencies
        )
        onFrame?(frame)
    }

    private func applyConfiguration() {
        fftProcessor.fftSize = configuration.fftSize
        bandMapper = BandMapper(
            bandCount: configuration.bandCount,
            frequencyRange: configuration.frequencyRange
        )
    }
}
