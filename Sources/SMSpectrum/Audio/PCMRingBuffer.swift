import Foundation

/// Single-producer / single-consumer ring buffer for `Float` PCM samples.
///
/// The audio thread (producer) appends incoming samples; the DSP thread
/// (consumer) reads `fftSize` samples per FFT. Capacity should be ≥ 2 *
/// `fftSize` to avoid overruns at high band counts.
final class PCMRingBuffer {

    private var storage: [Float]
    private let capacity: Int
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private let lock = NSLock()

    init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        self.storage = [Float](repeating: 0, count: capacity)
    }

    var availableForRead: Int {
        lock.lock(); defer { lock.unlock() }
        return (writeIndex - readIndex + capacity) % capacity
    }

    func write(_ samples: UnsafePointer<Float>, count: Int) {
        lock.lock(); defer { lock.unlock() }
        for i in 0..<count {
            storage[writeIndex] = samples[i]
            writeIndex = (writeIndex + 1) % capacity
            if writeIndex == readIndex {
                // Buffer overflow — advance read head, dropping oldest sample.
                readIndex = (readIndex + 1) % capacity
            }
        }
    }

    /// Reads up to `count` samples into `destination` without consuming them.
    /// Returns the actual number copied.
    @discardableResult
    func peek(into destination: UnsafeMutablePointer<Float>, count: Int) -> Int {
        lock.lock(); defer { lock.unlock() }
        let available = (writeIndex - readIndex + capacity) % capacity
        let toRead = min(count, available)
        for i in 0..<toRead {
            destination[i] = storage[(readIndex + i) % capacity]
        }
        return toRead
    }

    /// Advances the read cursor by `count` samples.
    func consume(_ count: Int) {
        lock.lock(); defer { lock.unlock() }
        let available = (writeIndex - readIndex + capacity) % capacity
        let advance = min(count, available)
        readIndex = (readIndex + advance) % capacity
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        writeIndex = 0
        readIndex = 0
    }
}
