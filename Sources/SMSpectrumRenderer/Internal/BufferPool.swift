import Foundation
import Metal

/// Round-robin pool of `MTLBuffer` slots, one per in-flight frame.
///
/// Each call to `nextBuffer(byteCount:)` returns a buffer reused across frames,
/// reallocating only if the requested size grows. Caller must not retain
/// references across frames beyond `SpectrumRenderer.maxInFlightFrames`.
final class BufferPool {

    private struct Slot {
        var buffers: [String: MTLBuffer] = [:]
    }

    private let device: MTLDevice
    private var slots: [Slot]
    private var cursor: Int = 0
    private let lock = NSLock()

    init(device: MTLDevice, capacity: Int) {
        self.device = device
        self.slots = Array(repeating: Slot(), count: max(1, capacity))
    }

    /// Advances the round-robin cursor. Call once per frame before encoding.
    func advance() {
        lock.lock()
        defer { lock.unlock() }
        cursor = (cursor + 1) % slots.count
    }

    /// Returns a buffer for `key` in the current slot, growing it if necessary.
    func buffer(forKey key: String, byteCount: Int) throws -> MTLBuffer {
        lock.lock()
        defer { lock.unlock() }

        var slot = slots[cursor]
        if let existing = slot.buffers[key], existing.length >= byteCount {
            return existing
        }

        guard let buffer = device.makeBuffer(length: byteCount, options: .storageModeShared) else {
            throw RenderError.bufferAllocationFailed(byteCount: byteCount)
        }
        buffer.label = "SMSpectrum.\(key).slot\(cursor)"
        slot.buffers[key] = buffer
        slots[cursor] = slot
        return buffer
    }
}
