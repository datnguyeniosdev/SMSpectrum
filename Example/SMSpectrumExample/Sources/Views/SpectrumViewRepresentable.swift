import SwiftUI
import SMSpectrum

/// SwiftUI bridge for `SMSpectrumView`.
///
/// Demonstrates the split between the display view (`SMSpectrumView`) and
/// the audio adapter (`SMAudioSpectrumDriver`): the view is created once,
/// the driver is rebuilt when the source changes.
struct SpectrumViewRepresentable: UIViewRepresentable {

    let source: SMSource
    let configuration: SMConfiguration
    var onError: ((SMError) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onError: onError)
    }

    func makeUIView(context: Context) -> SMSpectrumView {
        do {
            let view = try SMSpectrumView(frame: .zero, configuration: configuration)
            view.spectrumDelegate = context.coordinator
            context.coordinator.attach(view: view, source: source, configuration: configuration)
            return view
        } catch let error as SMError {
            context.coordinator.report(error)
            return Self.fallbackView()
        } catch {
            context.coordinator.report(.rendererInitializationFailed(underlying: error))
            return Self.fallbackView()
        }
    }

    func updateUIView(_ uiView: SMSpectrumView, context: Context) {
        uiView.configuration = configuration
        context.coordinator.update(source: source, configuration: configuration)
    }

    private static func fallbackView() -> SMSpectrumView {
        guard let view = try? SMSpectrumView(frame: .zero, configuration: .digital) else {
            fatalError("SMSpectrum demo requires Metal-capable hardware.")
        }
        return view
    }

    final class Coordinator: NSObject, SMSpectrumViewDelegate {

        let onError: ((SMError) -> Void)?
        private weak var view: SMSpectrumView?
        private var driver: SMAudioSpectrumDriver?
        private var lastSource: SMSource?

        init(onError: ((SMError) -> Void)?) {
            self.onError = onError
        }

        func attach(view: SMSpectrumView, source: SMSource, configuration: SMConfiguration) {
            self.view = view
            startDriver(source: source, configuration: configuration)
        }

        func update(source: SMSource, configuration: SMConfiguration) {
            driver?.configuration = configuration
            if !sourcesEqual(source, lastSource) {
                driver?.stop()
                startDriver(source: source, configuration: configuration)
            }
        }

        func report(_ error: SMError) {
            onError?(error)
        }

        // MARK: - SMSpectrumViewDelegate

        func spectrumView(_ view: SMSpectrumView, didProduce frame: SMSpectrumFrame) {
            // Demo doesn't use the analysis output, but this hook is where you
            // would forward `frame.magnitudes` / `frame.bandFrequencies` to
            // your own analytics, recording, etc.
        }

        func spectrumView(_ view: SMSpectrumView, didFailWith error: SMError) {
            onError?(error)
        }

        // MARK: - Private

        private func startDriver(source: SMSource, configuration: SMConfiguration) {
            guard let view else { return }
            let driver = SMAudioSpectrumDriver(configuration: configuration)
            driver.attach(to: view)
            driver.onError = { [weak self] error in
                self?.onError?(error)
            }
            do {
                try driver.start(source: source)
            } catch let error as SMError {
                onError?(error)
            } catch {
                onError?(.audioEngineFailedToStart(underlying: error))
            }
            self.driver = driver
            self.lastSource = source
        }

        private func sourcesEqual(_ lhs: SMSource, _ rhs: SMSource?) -> Bool {
            guard let rhs else { return false }
            switch (lhs, rhs) {
            case (.microphone, .microphone), (.manual, .manual):
                return true
            case (.file(let a), .file(let b)):
                return a == b
            case (.audioEngine, .audioEngine):
                return true  // can't compare engine instances meaningfully
            default:
                return false
            }
        }
    }
}
