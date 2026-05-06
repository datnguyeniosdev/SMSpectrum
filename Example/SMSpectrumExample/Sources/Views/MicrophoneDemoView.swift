import SwiftUI
import SMSpectrum

struct MicrophoneDemoView: View {

    @State private var style: SMStyle = .digital
    @State private var bandCount: Double = 96
    @State private var softness: Double = 0.6
    @State private var circleMode: SMCircleMode = .cubicHermite
    @State private var orientation: SMOrientation = .horizontal
    @State private var sideMode: SMSide = .both
    @State private var bloomEnabled: Bool = true
    @State private var bloomIntensity: Double = 0.8
    @State private var bloomThreshold: Double = 0.4
    @State private var bloomRadius: Double = 14
    @State private var circleMirror: Double = 0.25
    @State private var circleMirrorPhase: Double = 0
    @State private var circularTemplate: CircularTemplate = .off
    @State private var processedData: Bool = false
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
                circleMode: $circleMode,
                orientation: $orientation,
                sideMode: $sideMode,
                bloomEnabled: $bloomEnabled,
                bloomIntensity: $bloomIntensity,
                bloomThreshold: $bloomThreshold,
                bloomRadius: $bloomRadius,
                circleMirror: $circleMirror,
                circleMirrorPhase: $circleMirrorPhase,
                circularTemplate: $circularTemplate,
                processedData: $processedData
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
        let isCircleBars = (style == .circle && circleMode == .bars)
        let isCircleHermite = (style == .circle && circleMode == .cubicHermite)
        let isCircleLine = (style == .circleLine)
        let twoPi = CGFloat.pi * 2
        return SMConfiguration(
            style: style,
            bandCount: Int(bandCount),
            maxHeight: isCircleHermite ? 70 : (isCircleBars ? 80 : (isCircleLine ? 80 : 60)),
            thickness: isCircleBars ? 2 : 6,
            softness: Float(softness),
            sideMode: sideMode,
            smoothing: .silky,
            bandSmoothing: 0.7,
            circleMode: circleMode,
            circleBaseRadius: isCircleLine ? 130 : (isCircleHermite ? 100 : DemoCircleLayers.baseRadius),
            layers: isCircleHermite ? DemoCircleLayers.quadrants
                : (isCircleLine ? [SMLayer(range: 0...twoPi, gradient: .cyanMagenta, thickness: 1.8)] : []),
            bloomFilter: bloomEnabled
                ? SMBloomFilter(
                    intensity: Float(bloomIntensity),
                    threshold: Float(bloomThreshold),
                    radius: Float(bloomRadius)
                )
                    : nil,
            circleMirror: Float(circleMirror),
            circleMirrorPhase: Float(circleMirrorPhase),
            processedData: processedData,
            orientation: orientation
        )
    }
}

#Preview {
    MicrophoneDemoView()
}
