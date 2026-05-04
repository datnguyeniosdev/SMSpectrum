import Foundation
import simd
import SMSpectrumRenderer

#if canImport(UIKit)
import UIKit
public typealias SMColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias SMColor = NSColor
#endif

/// Color gradient applied along the band axis.
public struct SMColorGradient: Equatable {
    public var colors: [SMColor]
    public var dynamicHue: Bool
    public var hueSpeed: Float

    public init(colors: [SMColor], dynamicHue: Bool = false, hueSpeed: Float = 0.1) {
        precondition(colors.count >= 2, "Gradient requires at least two colors.")
        self.colors = colors
        self.dynamicHue = dynamicHue
        self.hueSpeed = hueSpeed
    }

    public static func == (lhs: SMColorGradient, rhs: SMColorGradient) -> Bool {
        lhs.dynamicHue == rhs.dynamicHue
            && lhs.hueSpeed == rhs.hueSpeed
            && lhs.colors.count == rhs.colors.count
            && zip(lhs.colors, rhs.colors).allSatisfy { $0.isEqual($1) }
    }
}

extension SMColorGradient {
    var renderGradient: RenderColorGradient {
        let stops = colors.map { color -> SIMD4<Float> in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
            #if canImport(UIKit)
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            #elseif canImport(AppKit)
            color.usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
            #endif
            return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
        }
        return RenderColorGradient(stops: stops, dynamicPhase: dynamicHue, phaseSpeed: hueSpeed)
    }
}

extension SMColorGradient {
    public static let cyanMagenta = SMColorGradient(
        colors: [.cyan, .magenta]
    )

    public static let warmSunset = SMColorGradient(
        colors: [
            SMColor(red: 1.0, green: 0.45, blue: 0.2, alpha: 1.0),
            SMColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        ]
    )

    /// Full HSV-style rainbow loop — useful for circular spectrums where each
    /// band gets a distinct hue.
    public static let rainbow = SMColorGradient(
        colors: [
            SMColor(red: 1.00, green: 0.20, blue: 0.30, alpha: 1.0),  // red
            SMColor(red: 1.00, green: 0.55, blue: 0.10, alpha: 1.0),  // orange
            SMColor(red: 1.00, green: 0.90, blue: 0.20, alpha: 1.0),  // yellow
            SMColor(red: 0.30, green: 0.95, blue: 0.40, alpha: 1.0),  // green
            SMColor(red: 0.20, green: 0.85, blue: 1.00, alpha: 1.0),  // cyan
            SMColor(red: 0.40, green: 0.40, blue: 1.00, alpha: 1.0),  // blue
            SMColor(red: 0.85, green: 0.35, blue: 1.00, alpha: 1.0),  // violet
            SMColor(red: 1.00, green: 0.20, blue: 0.30, alpha: 1.0)   // back to red
        ]
    )
}
