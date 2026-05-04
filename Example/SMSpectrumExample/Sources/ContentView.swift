import SwiftUI

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
        }
    }
}

#Preview {
    ContentView()
}
