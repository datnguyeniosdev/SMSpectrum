import Foundation

/// Top-level error type surfaced by `SMSpectrumView` and supporting services.
public enum SMError: Error, CustomStringConvertible {
    case audioSessionConfigurationFailed(underlying: Error)
    case microphonePermissionDenied
    case audioFileLoadFailed(URL, underlying: Error)
    case audioEngineFailedToStart(underlying: Error)
    case rendererInitializationFailed(underlying: Error)
    case renderFailed(underlying: Error)
    case unsupportedFormat(reason: String)
    case invalidConfiguration(reason: String)

    public var description: String {
        switch self {
        case .audioSessionConfigurationFailed(let e):
            return "Audio session configuration failed: \(e)"
        case .microphonePermissionDenied:
            return "Microphone permission denied."
        case .audioFileLoadFailed(let url, let e):
            return "Failed to load audio file at \(url.lastPathComponent): \(e)"
        case .audioEngineFailedToStart(let e):
            return "Audio engine failed to start: \(e)"
        case .rendererInitializationFailed(let e):
            return "Renderer initialization failed: \(e)"
        case .renderFailed(let e):
            return "Render failed: \(e)"
        case .unsupportedFormat(let reason):
            return "Unsupported audio format: \(reason)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        }
    }
}
