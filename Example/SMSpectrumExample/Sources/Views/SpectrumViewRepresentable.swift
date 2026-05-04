import SwiftUI
import SMSpectrum

/// SwiftUI bridge for `SMSpectrumView` (a `UIView` subclass).
struct SpectrumViewRepresentable: UIViewRepresentable {

    let source: SMSource
    let configuration: SMConfiguration
    var onError: ((SMError) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onError: onError)
    }

    func makeUIView(context: Context) -> SMSpectrumView {
        do {
            let view = try SMSpectrumView(
                frame: .zero,
                configuration: configuration,
                source: source
            )
            view.spectrumDelegate = context.coordinator
            view.start()
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
        uiView.source = source
    }

    private static func fallbackView() -> SMSpectrumView {
        // If the manual fallback fails the host has no usable Metal device, which is
        // unrecoverable for a visualization demo.
        guard let view = try? SMSpectrumView(frame: .zero, configuration: .digital, source: .manual) else {
            fatalError("SMSpectrum demo requires Metal-capable hardware.")
        }
        return view
    }

    final class Coordinator: NSObject, SMSpectrumViewDelegate {
        let onError: ((SMError) -> Void)?

        init(onError: ((SMError) -> Void)?) {
            self.onError = onError
        }

        func report(_ error: SMError) {
            onError?(error)
        }

        func spectrumView(_ view: SMSpectrumView, didFailWith error: SMError) {
            onError?(error)
        }
    }
}
