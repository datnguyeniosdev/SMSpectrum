import SwiftUI
import UniformTypeIdentifiers
import SMSpectrum

struct AudioFileDemoView: View {

    @State private var style: SMStyle = .analogLines
    @State private var bandCount: Double = 64
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
    @State private var selectedURL: URL? = Bundle.main.url(forResource: "demo", withExtension: "mp3")
    @State private var fileName: String?
    @State private var isImporterPresented = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if let url = selectedURL {
                SpectrumViewRepresentable(
                    source: .file(url),
                    configuration: configuration,
                    onError: { errorMessage = $0.description }
                )
                .frame(height: 280)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            } else {
                placeholder
            }

            Button {
                isImporterPresented = true
            } label: {
                Label(fileName ?? "Choose Audio File", systemImage: "folder.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
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
                circularTemplate: $circularTemplate
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
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.audio, .mp3, .wav, .mpeg4Audio],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .onDisappear { releaseSecurityScopedResource() }
    }

    private var configuration: SMConfiguration {
        let isCircleBars = (style == .circle && circleMode == .bars)
        let isCircleHermite = (style == .circle && circleMode == .cubicHermite)
        let isCircleLine = (style == .circleLine)
        let twoPi = CGFloat.pi * 2
        return SMConfiguration(
            style: style,
            bandCount: Int(bandCount),
            maxHeight: isCircleHermite ? 200 : (isCircleBars ? 80 : (isCircleLine ? 80 : 60)),
            thickness: isCircleBars ? 2 : 6,
            softness: Float(softness),
            sideMode: sideMode,
            smoothing: .silky,
            bandSmoothing: 0.7,
            circleMode: circleMode,
            circleBaseRadius: isCircleLine ? 130 : DemoCircleLayers.baseRadius,
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
            orientation: orientation
        )
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.black.opacity(0.85))
            .frame(height: 280)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Pick an audio file from Files to start")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            )
            .padding(.horizontal)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        errorMessage = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            releaseSecurityScopedResource()
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Couldn't open the selected file (security-scoped access denied)."
                return
            }
            selectedURL = url
            fileName = url.lastPathComponent
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func releaseSecurityScopedResource() {
        selectedURL?.stopAccessingSecurityScopedResource()
    }
}

#Preview {
    AudioFileDemoView()
}
