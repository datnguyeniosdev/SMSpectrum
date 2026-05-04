import SwiftUI
import SMSpectrum

struct MicrophoneDemoView: View {

    @State private var style: SMStyle = .digital
    @State private var bandCount: Double = 96
    @State private var softness: Double = 0.3
    @State private var circleMode: SMCircleMode = .cubicHermite
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            SpectrumViewRepresentable(
                source: .microphone,
                configuration: configuration,
                onError: { errorMessage = $0.description }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            ConfigurationPanel(
                style: $style,
                bandCount: $bandCount,
                softness: $softness,
                circleMode: $circleMode
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 24)
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private var configuration: SMConfiguration {
        let isCircleHermite = (style == .circle && circleMode == .cubicHermite)
        return SMConfiguration(
            style: style,
            bandCount: Int(bandCount),
            // Bumps ~25% of ring radius for circle hermite so the silhouette
            // reads as "circle with waves" instead of an amorphous blob.
            maxHeight: isCircleHermite ? 22 : 60,
            softness: Float(softness),
            smoothing: .silky,
            bandSmoothing: 0.7,
            circleMode: circleMode,
            circleBaseRadius: DemoCircleLayers.baseRadius,
            layers: isCircleHermite ? DemoCircleLayers.ribbon : []
        )
    }
}

#Preview {
    MicrophoneDemoView()
}
