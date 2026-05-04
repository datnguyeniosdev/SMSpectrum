import SwiftUI
import SMSpectrum

struct ConfigurationPanel: View {

    @Binding var style: SMStyle
    @Binding var bandCount: Double
    @Binding var softness: Double
    @Binding var circleMode: SMCircleMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Style", selection: $style) {
                Text("Digital").tag(SMStyle.digital)
                Text("Lines").tag(SMStyle.analogLines)
                Text("Dots").tag(SMStyle.analogDots)
                Text("Circle").tag(SMStyle.circle)
                Text("Gradient").tag(SMStyle.lineGradient)
                Text("Wave").tag(SMStyle.waveform)
            }
            .pickerStyle(.segmented)

            if style == .circle {
                Picker("Circle Mode", selection: $circleMode) {
                    Text("Bars").tag(SMCircleMode.bars)
                    Text("Cubic Hermite").tag(SMCircleMode.cubicHermite)
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading) {
                Text("Bands: \(Int(bandCount))")
                    .font(.footnote.monospacedDigit())
                Slider(value: $bandCount, in: 16...256, step: 1)
            }

            VStack(alignment: .leading) {
                Text(String(format: "Softness: %.2f", softness))
                    .font(.footnote.monospacedDigit())
                Slider(value: $softness, in: 0...1)
            }
        }
        .padding(.horizontal)
    }
}
