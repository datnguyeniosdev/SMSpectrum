import SwiftUI
import SMSpectrum

enum CircularTemplate: String, CaseIterable, Identifiable {
    case off
    case mirroredBars
    case mirroredHermite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .mirroredBars: return "Bars"
        case .mirroredHermite: return "Hermite"
        }
    }
}

struct ConfigurationPanel: View {

    @Binding var style: SMStyle
    @Binding var bandCount: Double
    @Binding var softness: Double
    @Binding var circleMode: SMCircleMode
    @Binding var orientation: SMOrientation
    @Binding var sideMode: SMSide

    @Binding var bloomEnabled: Bool
    @Binding var bloomIntensity: Double
    @Binding var bloomThreshold: Double
    @Binding var bloomRadius: Double

    @Binding var circleMirror: Double
    @Binding var circleMirrorPhase: Double

    @Binding var circularTemplate: CircularTemplate

    @Binding var processedData: Bool

    /// Line-based styles honor orientation + side; circle styles ignore both.
    private var supportsOrientation: Bool { style != .circle && style != .circleLine }
    private var isCircleStyle: Bool { style == .circle || style == .circleLine }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Style", selection: $style) {
                    Text("Digital").tag(SMStyle.digital)
                    Text("Lines").tag(SMStyle.analogLines)
                    Text("Dots").tag(SMStyle.analogDots)
                    Text("Circle").tag(SMStyle.circle)
                    Text("C.Line").tag(SMStyle.circleLine)
                    Text("Gradient").tag(SMStyle.lineGradient)
                    Text("Wave").tag(SMStyle.waveform)
                }
                .pickerStyle(.segmented)

                if isCircleStyle {
                    Picker("Template", selection: $circularTemplate) {
                        Text("Off").tag(CircularTemplate.off)
                        Text("Mirror Bars").tag(CircularTemplate.mirroredBars)
                        Text("Mirror Herm").tag(CircularTemplate.mirroredHermite)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: circularTemplate) { newValue in
                        applyTemplate(newValue)
                    }

                    if circularTemplate == .off {
                        VStack(alignment: .leading) {
                            Text(String(format: "Mirror: %.0f%%", circleMirror * 100))
                                .font(.footnote.monospacedDigit())
                            Slider(value: $circleMirror, in: 0...1, step: 0.05)
                        }

                        VStack(alignment: .leading) {
                            Text(String(format: "Phase: %.2f", circleMirrorPhase))
                                .font(.footnote.monospacedDigit())
                            Slider(value: $circleMirrorPhase, in: 0...1, step: 0.05)
                        }
                    }
                }

                if supportsOrientation {
                    Picker("Orientation", selection: $orientation) {
                        Text("Horizontal").tag(SMOrientation.horizontal)
                        Text("Vertical").tag(SMOrientation.vertical)
                    }
                    .pickerStyle(.segmented)

                    Picker("Side", selection: $sideMode) {
                        Text(orientation == .vertical ? "Right" : "Top").tag(SMSide.sideA)
                        Text(orientation == .vertical ? "Left" : "Bottom").tag(SMSide.sideB)
                        Text("Both").tag(SMSide.both)
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading) {
                    Text("Bands: \(Int(bandCount))")
                        .font(.footnote.monospacedDigit())
                    Slider(value: $bandCount, in: 16...1000, step: 1)
                }

                VStack(alignment: .leading) {
                    Text(String(format: "Softness: %.2f", softness))
                        .font(.footnote.monospacedDigit())
                    Slider(value: $softness, in: 0...1)
                }

            Toggle("Bloom", isOn: $bloomEnabled)
                .font(.footnote.weight(.semibold))

            Toggle("Processed", isOn: $processedData)
                .font(.footnote.weight(.semibold))

            if bloomEnabled {
                    VStack(alignment: .leading) {
                        Text(String(format: "Intensity: %.2f", bloomIntensity))
                            .font(.footnote.monospacedDigit())
                        Slider(value: $bloomIntensity, in: 0...2)
                    }

                    VStack(alignment: .leading) {
                        Text(String(format: "Threshold: %.2f", bloomThreshold))
                            .font(.footnote.monospacedDigit())
                        Slider(value: $bloomThreshold, in: 0...1)
                    }

                    VStack(alignment: .leading) {
                        Text(String(format: "Radius: %.0fpt", bloomRadius))
                            .font(.footnote.monospacedDigit())
                        Slider(value: $bloomRadius, in: 1...40)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func applyTemplate(_ template: CircularTemplate) {
        switch template {
        case .off:
            break
        case .mirroredBars:
            circleMirror = 0.25
            circleMirrorPhase = 0
            bloomEnabled = true
            bloomIntensity = 0.5
            bloomThreshold = 0.3
            bloomRadius = 12
            circleMode = .bars
        case .mirroredHermite:
            circleMirror = 0.25
            circleMirrorPhase = 0
            bloomEnabled = true
            bloomIntensity = 0.5
            bloomThreshold = 0.3
            bloomRadius = 12
            circleMode = .cubicHermite
        }
    }
}
