import Foundation

/// Attack/release smoothing applied to spectrum magnitudes between frames.
///
/// Values are time constants in seconds. Lower attack = faster rise, higher
/// release = slower fall (longer tails). Both must be > 0.
public struct SMSmoothing: Equatable {
    public var attack: TimeInterval
    public var release: TimeInterval

    public init(attack: TimeInterval = 0.04, release: TimeInterval = 0.30) {
        precondition(attack > 0 && release > 0, "Smoothing time constants must be positive.")
        self.attack = attack
        self.release = release
    }

    public static let snappy = SMSmoothing(attack: 0.005, release: 0.08)
    public static let balanced = SMSmoothing(attack: 0.04, release: 0.30)
    public static let smooth = SMSmoothing(attack: 0.08, release: 0.5)
    public static let silky = SMSmoothing(attack: 0.12, release: 0.7)
}
