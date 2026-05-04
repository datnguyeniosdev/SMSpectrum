import Metal

enum MetalDeviceProvider {

    /// Returns the system default Metal device, throwing `RenderError` if unavailable.
    static func makeSystemDefaultDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RenderError.metalDeviceUnavailable
        }
        return device
    }
}
