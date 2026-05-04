import Foundation
import AVFoundation

/// Owns `AVAudioEngine` setup for the supported `SMSource` cases and forwards
/// PCM buffers via callbacks. Does NOT perform DSP — that is the
/// `FFTProcessor`'s job, dispatched off the audio thread.
final class AudioEngine {

    var onPCMBuffer: ((AVAudioPCMBuffer, Double, TimeInterval) -> Void)?
    var onError: ((SMError) -> Void)?

    private let engine = AVAudioEngine()
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var tappedNode: AVAudioNode?
    private var sourceStartTime: TimeInterval = 0

    private static let bufferSize: AVAudioFrameCount = 1024

    func start(source: SMSource) throws {
        stop()
        sourceStartTime = CFAbsoluteTimeGetCurrent()

        switch source {
        case .file(let url):
            try startFile(url: url)
        case .microphone:
            try startMicrophone()
        case .audioEngine(let externalEngine, let node):
            try startExternal(engine: externalEngine, node: node)
        case .manual:
            // Host pushes buffers directly; nothing to start.
            return
        }
    }

    func pause() {
        engine.pause()
        playerNode?.pause()
    }

    func stop() {
        playerNode?.stop()
        if let tapped = tappedNode {
            tapped.removeTap(onBus: 0)
        }
        if engine.isRunning {
            engine.stop()
        }
        playerNode = nil
        audioFile = nil
        tappedNode = nil
    }

    // MARK: - Source helpers

    private func startFile(url: URL) throws {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw SMError.audioFileLoadFailed(url, underlying: error)
        }
        self.audioFile = file

        let player = AVAudioPlayerNode()
        self.playerNode = player

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)

        installTap(on: player, format: file.processingFormat)
        try startEngine()

        player.scheduleFile(file, at: nil, completionHandler: nil)
        player.play()
    }

    private func startMicrophone() throws {
        try configureSessionForRecording()

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        installTap(on: input, format: format)
        try startEngine()
    }

    private func startExternal(engine externalEngine: AVAudioEngine, node: AVAudioNode) throws {
        // External engine lifecycle is owned by the host; we only attach a tap.
        let format = node.outputFormat(forBus: 0)
        installTap(on: node, format: format)
    }

    private func installTap(on node: AVAudioNode, format: AVAudioFormat) {
        node.installTap(onBus: 0, bufferSize: Self.bufferSize, format: format) { [weak self] buffer, time in
            guard let self = self else { return }
            let now = CFAbsoluteTimeGetCurrent() - self.sourceStartTime
            self.onPCMBuffer?(buffer, format.sampleRate, now)
            _ = time
        }
        tappedNode = node
    }

    private func startEngine() throws {
        engine.prepare()
        do {
            try engine.start()
        } catch {
            throw SMError.audioEngineFailedToStart(underlying: error)
        }
    }

    private func configureSessionForRecording() throws {
        #if os(iOS) || os(tvOS) || os(watchOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try session.setActive(true, options: [])
        } catch {
            throw SMError.audioSessionConfigurationFailed(underlying: error)
        }
        #endif
    }
}
