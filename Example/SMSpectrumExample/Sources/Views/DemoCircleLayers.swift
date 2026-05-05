import CoreGraphics
import SMSpectrum

#if canImport(UIKit)
import UIKit
#endif

/// Demo-friendly Cubic Hermite layer presets sized for the 280pt-tall preview
/// containers used by `MicrophoneDemoView` and `AudioFileDemoView`.
///
/// All layers share the same ring (`circleBaseRadius` + `maxHeight` on
/// `SMConfiguration`); each entry covers a different angular slice with its
/// own gradient. `SMLayer.range` is in radians for circle styles.
enum DemoCircleLayers {

    /// Inner ring radius (pt) used by the demo container. Big enough that the
    /// audio bumps (`maxHeight` ~25pt) read as ~25% of the ring rather than
    /// dominating the silhouette, so the visual stays "circle with waves"
    /// instead of "amorphous blob".
    static let baseRadius: CGFloat = 150

    /// Half circle split into two equal quadrants. Demonstrates partial-arc
    /// rendering cleanly — only the right half of the ring is drawn.
    static let quadrants: [SMLayer] = {
        let twoPi = CGFloat.pi * 2
        return [
            SMLayer(range: 0...twoPi,   gradient: .cyanMagenta, thickness: 0.8),
        ]
    }()

    /// 40 thin curves stacked with small radial + phase offsets, producing
    /// the woven cyan/violet ribbon glow seen in the reference design.
    static let ribbon: [SMLayer] = SMLayer.circleRibbon(
        count: 8,
        radialSpread: 18,        // narrow ribbon band (≈20% of baseRadius)
        phaseSpread: 0.45,
        gradient: ribbonGradient,
        thickness: 0.8
    )

    private static var ribbonGradient: SMColorGradient {
        SMColorGradient(colors: [
            SMColor(red: 0.15, green: 0.55, blue: 1.00, alpha: 1.0),  // cyan-blue
            SMColor(red: 0.45, green: 0.35, blue: 1.00, alpha: 1.0),  // violet
            SMColor(red: 0.85, green: 0.30, blue: 1.00, alpha: 1.0),  // magenta-pink
            SMColor(red: 0.30, green: 0.55, blue: 1.00, alpha: 1.0),  // cyan-blue (loop)
            SMColor(red: 0.15, green: 0.55, blue: 1.00, alpha: 1.0)
        ])
    }
}
