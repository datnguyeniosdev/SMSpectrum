import Foundation
import os

/// Lightweight wrapper over `os.Logger` (iOS 14+) with a `print` fallback for iOS 13.
struct Logger {
    private let subsystem: String
    private let category: String

    init(category: String) {
        self.subsystem = "com.darrennguyen.smspectrum"
        self.category = category
    }

    func info(_ message: @autoclosure () -> String) {
        emit(level: "INFO", message: message())
    }

    func warning(_ message: @autoclosure () -> String) {
        emit(level: "WARN", message: message())
    }

    func error(_ message: @autoclosure () -> String) {
        emit(level: "ERROR", message: message())
    }

    private func emit(level: String, message: String) {
        if #available(iOS 14.0, macOS 11.0, macCatalyst 14.0, *) {
            let logger = os.Logger(subsystem: subsystem, category: category)
            logger.log("\(level, privacy: .public) \(message, privacy: .public)")
        } else {
            #if DEBUG
            print("[\(subsystem):\(category)] \(level) \(message)")
            #endif
        }
    }
}
