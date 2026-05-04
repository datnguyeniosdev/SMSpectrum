import SwiftUI
import UniformTypeIdentifiers
import SMSpectrum

struct AudioFileDemoView: View {

    @State private var style: SMStyle = .analogLines
    @State private var bandCount: Double = 64
    @State private var softness: Double = 0.4
    @State private var circleMode: SMCircleMode = .cubicHermite
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
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.audio, .mp3, .wav, .mpeg4Audio],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .onDisappear { releaseSecurityScopedResource() }
    }

    private var configuration: SMConfiguration {
        let isCircleHermite = (style == .circle && circleMode == .cubicHermite)
        return SMConfiguration(
            style: style,
            bandCount: Int(bandCount),
            maxHeight: isCircleHermite ? 22 : 60,
            softness: Float(softness),
            smoothing: .silky,
            bandSmoothing: 0.7,
            circleMode: circleMode,
            circleBaseRadius: DemoCircleLayers.baseRadius,
            layers: isCircleHermite ? DemoCircleLayers.ribbon : []
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
