import SwiftUI
import SMSpectrum

struct ContentView: View {
    var body: some View {
        TabView {
            MicrophoneDemoView()
                .tabItem {
                    Label("Microphone", systemImage: "mic.fill")
                }
            AudioFileDemoView()
                .tabItem {
                    Label("File", systemImage: "waveform")
                }
            CircleLinePreviewView()
                .tabItem {
                    Label("CircleLine", systemImage: "circle.dotted")
                }
        }
    }
}

struct CircleLinePreviewView: View {
    @State private var circleMirror: Double = 0.25
    @State private var circleMirrorPhase: Double = 0
    @State private var softness: Double = 0.4
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            SpectrumViewRepresentable(
                source: .microphone,
                configuration: configuration,
                onError: { errorMessage = $0.description }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: "Mirror: %.0f%%", circleMirror * 100))
                    .font(.footnote.monospacedDigit())
                Slider(value: $circleMirror, in: 0...1, step: 0.05)

                Text(String(format: "Phase: %.2f", circleMirrorPhase))
                    .font(.footnote.monospacedDigit())
                Slider(value: $circleMirrorPhase, in: 0...1, step: 0.05)

                Text(String(format: "Softness: %.2f", softness))
                    .font(.footnote.monospacedDigit())
                Slider(value: $softness, in: 0...1)
            }
            .padding(.horizontal)

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
        let twoPi = CGFloat.pi * 2
        return SMConfiguration(
            style: .circleLine,
            bandCount: 128,
            maxHeight: 80,
            thickness: 0,
            softness: Float(softness),
            path: .circle(center: CGPoint(x: 0.5, y: 0.5), radius: 0.38),
            gradient: .cyanMagenta,
            sideMode: .sideA,
            smoothing: .silky,
            bandSmoothing: 0.6,
            circleBaseRadius: 130,
            layers: [
                SMLayer(
                    range: 0...twoPi,
                    gradient: .cyanMagenta,
                    thickness: 1.8
                )
            ],
            bloomFilter: SMBloomFilter(intensity: 0.5, threshold: 0.25, radius: 10),
            circleMirror: Float(circleMirror),
            circleMirrorPhase: Float(circleMirrorPhase)
        )
    }
}

#Preview {
    ContentView()
}
