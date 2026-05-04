import Foundation

/// Minimal `os_unfair_lock`-backed atomic wrapper. Use only for primitive
/// values where Swift's built-in actor isolation is overkill.
@propertyWrapper
final class Atomic<Value> {
    private var storage: Value
    private var lock = os_unfair_lock_s()

    init(wrappedValue: Value) {
        self.storage = wrappedValue
    }

    var wrappedValue: Value {
        get {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            return storage
        }
        set {
            os_unfair_lock_lock(&lock)
            storage = newValue
            os_unfair_lock_unlock(&lock)
        }
    }

    func mutate(_ transform: (inout Value) -> Void) {
        os_unfair_lock_lock(&lock)
        transform(&storage)
        os_unfair_lock_unlock(&lock)
    }
}
