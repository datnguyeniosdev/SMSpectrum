import Foundation

/// Lock-protected ring buffer that holds the most recent N magnitude frames.
///
/// The DSP thread writes; the render thread reads the latest entry. Frames
/// older than `capacity` are silently dropped.
final class SpectrumRingBuffer {

    private struct Entry {
        var magnitudes: [Float]
        var timestamp: TimeInterval
    }

    private let capacity: Int
    private var entries: [Entry?]
    private var writeIndex: Int = 0
    private let lock = NSLock()

    init(capacity: Int = 4) {
        precondition(capacity > 0)
        self.capacity = capacity
        self.entries = Array(repeating: nil, count: capacity)
    }

    func push(magnitudes: [Float], timestamp: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        entries[writeIndex] = Entry(magnitudes: magnitudes, timestamp: timestamp)
        writeIndex = (writeIndex + 1) % capacity
    }

    /// Returns the most recently pushed entry, if any.
    func latest() -> (magnitudes: [Float], timestamp: TimeInterval)? {
        lock.lock(); defer { lock.unlock() }
        let lastIndex = (writeIndex - 1 + capacity) % capacity
        guard let entry = entries[lastIndex] else { return nil }
        return (entry.magnitudes, entry.timestamp)
    }
}
