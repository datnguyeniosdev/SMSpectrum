import Foundation
import Metal

/// Loads and caches the default Metal library bundled with the renderer.
final class PipelineLibrary {

    let device: MTLDevice
    let library: MTLLibrary

    init(device: MTLDevice) throws {
        self.device = device
        do {
            self.library = try device.makeDefaultLibrary(bundle: .module)
        } catch {
            throw RenderError.shaderLibraryMissing
        }
    }

    func makeFunction(named name: String) throws -> MTLFunction {
        guard let function = library.makeFunction(name: name) else {
            throw RenderError.pipelineCreationFailed(
                stage: "function-lookup:\(name)",
                underlying: NSError(
                    domain: "SMSpectrumRenderer",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Function \(name) not found in default library."]
                )
            )
        }
        return function
    }
}
