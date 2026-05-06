import Foundation

/// Errors emitted by the renderer.
public enum RenderError: Error, CustomStringConvertible {
    case metalDeviceUnavailable
    case shaderLibraryMissing
    case pipelineCreationFailed(stage: String, underlying: Error)
    case bufferAllocationFailed(byteCount: Int)
    case invalidFrame(reason: String)

    public var description: String {
        switch self {
        case .metalDeviceUnavailable:
            return "No Metal device available on this hardware."
        case .shaderLibraryMissing:
            return "Default Metal library not found in the renderer bundle."
        case .pipelineCreationFailed(let stage, let underlying):
            return "Failed to create pipeline at stage \(stage): \(underlying)"
        case .bufferAllocationFailed(let byteCount):
            return "Failed to allocate Metal buffer of \(byteCount) bytes."
        case .invalidFrame(let reason):
            return "Invalid render frame: \(reason)"
        }
    }
}
