# SMSpectrum

A high-performance audio spectrum visualization SDK for iOS, inspired by Adobe After Effects' Audio Spectrum effect. Powered by Metal and Accelerate.

▶️ **[Watch Demo Video](demo.gif)**

> Version **0.1.0** — realtime audio visualization with symmetric circle support, peak animation, and timeline overlay.

## Features

- **9 render styles**: digital bars, analog lines, analog dots, radial bars, Cubic Hermite ring, circle line (stroke-only), line gradient, time-domain waveform, symmetric circle mirror
- **Symmetric circle rendering** — mirror spectrum around a closed ring with Tukey window tapering, configurable peak count (1–6), and inertia-based peak animation for smooth transitions
- **Peak animation** — peaks glide smoothly between frames with velocity tracking, fade-in/fade-out, and frequency-constrained widths
- **Processed vs raw toggle** — switch between enhanced/cooked data pipeline and raw magnitudes for all styles
- **Timeline ring** — inner circular progress ring synced to real audio playback time
- **Bass/Mid/Treble delegate** — three-band frequency energy for driving audio-reactive UI animations
- **Circle line style** — circular stroke tracing magnitudes around a ring (stroke only, no fill)
- **Custom dot/bar sizing** — `dotRadius` and `barWidth` overrides for analog dots and digital bars
- **Multiple audio sources**: file playback, microphone, external `AVAudioEngine` tap, manual PCM push
- **Bring-your-own-data** path: feed pre-computed magnitudes directly (network feed, simulation, custom DSP)
- Configurable frequency range, band count, FFT size, attack/release smoothing, color gradient, geometric path
- **Multi-layer rendering** — slice the path into segments, each with its own gradient and thickness
- Horizontal or vertical orientation for line-based styles, with one-sided or mirrored side modes
- **Post-process bloom** — separable gaussian at half resolution, style-agnostic
- Metal-powered renderer at 60/120 Hz with triple buffering
- Real-time DSP via `Accelerate.vDSP`
- Modular architecture: `SMSpectrumRenderer` is independent of the `SMSpectrum` audio layer

## Requirements

- iOS 13.0+ / Mac Catalyst 13.0+
- Xcode 13+ / Swift 5.5+
- Apple GPU family 3+ (iPhone 6s and newer)
- For microphone capture: `NSMicrophoneUsageDescription` in `Info.plist`

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/darrennguyen/SMSpectrum.git", from: "0.1.0")
]
```

The package vends two products:

- `SMSpectrum` — full SDK (view + audio engine + DSP). Most apps want this.
- `SMSpectrumRenderer` — Metal renderer only. Pull this in if you have your own audio pipeline and just want the GPU drawing.

### CocoaPods

```ruby
pod 'SMSpectrum', '~> 0.1'         # Core (default subspec — pulls in Renderer)
pod 'SMSpectrum/Renderer', '~> 0.1' # Renderer only
```

## Quick Start

```swift
import SMSpectrum

let view = try SMSpectrumView(configuration: .digital)
let driver = SMAudioSpectrumDriver(configuration: .digital)
driver.attach(to: view)
try driver.start(source: .microphone)
```

That's it — `SMSpectrumView` is a `MTKView` subclass, add it to your view hierarchy and it draws automatically.

See `Example/SMSpectrumExample` for a full SwiftUI demo app with microphone, file playback, and circle line preview tabs.

## Three ways to drive the view

`SMSpectrumView` is **display-only** — it consumes magnitudes and renders them. How those magnitudes are produced is up to you.

### 1. Built-in audio driver (microphone, file, AVAudioEngine)

```swift
let view = try SMSpectrumView(configuration: .digital)
let driver = SMAudioSpectrumDriver(configuration: .digital)
driver.attach(to: view)
driver.onError = { error in print("audio:", error) }

try driver.start(source: .microphone)
// ...later
driver.stop()
```

Available sources:

- `.file(URL)` — local audio file playback
- `.microphone` — live mic input via the shared audio session
- `.audioEngine(AVAudioEngine, node: AVAudioNode)` — taps an existing engine
- `.manual` — you push PCM buffers via `driver.push(pcmBuffer:sampleRate:time:)`

### 2. Bring-your-own data (no audio engine)

```swift
let view = try SMSpectrumView(configuration: .digital)

let frequencies = view.configuration.bandCenterFrequencies(sampleRate: 48_000)
view.push(magnitudes: myMagnitudes)
```

`push(magnitudes:)` is thread-safe. Smoothing is applied internally before rendering.

### 3. Renderer-only

```swift
import SMSpectrumRenderer

let renderer = try SpectrumRenderer()
renderer.attach(to: myMTKView)

let frame = RenderFrame(magnitudes: myMagnitudes, timestamp: CACurrentMediaTime(), style: myDescriptor)
try renderer.render(frame: frame, drawable: drawable, renderPassDescriptor: pass, viewportSize: size)
```

## Configuration

`SMConfiguration` is the single source of truth for visual style. Built-in presets:

| Preset                      | Style         | Notes |
| --------------------------- | ------------- | ----- |
| `.digital`                  | digital bars  | Highest performance, classic VU look |
| `.analogLines`              | polyline      | Smooth continuous curve with softness/glow |
| `.analogDots`               | dots          | One dot per band |
| `.circle`                   | radial bars   | Bars radiating outward from a circle |
| `.circleHermite`            | filled ring   | Donut sector fill — alpha fades inward |
| `.circleMirrored`           | radial bars   | Symmetric bars with mirror + bloom |
| `.circleHermiteMirrored`    | filled ring   | Symmetric Hermite curve with mirror + bloom |
| `.circleLine`               | circle stroke | Circular stroke trace — stroke only, no fill |
| `.circleWaveform`           | filled ring   | Snappier filled ring for transients |
| `.lineGradient`             | filled area   | Filled area under curve |
| `.waveform`                 | flat waveform | Thin solid line with sharp transients |

### Key configuration fields

```swift
var config = SMConfiguration.digital
config.style = .circleLine
config.bandCount = 128
config.maxHeight = 80
config.softness = 0.4
config.sideMode = .both
config.gradient = .cyanMagenta
config.smoothing = .silky
config.bandSmoothing = 0.6

// Circle mirror — symmetric display
config.circleMirror = 0.25        // 0…1 taper fraction
config.circleMirrorPhase = 0       // 0…1 rotation
config.circleMirrorPeaks = 4       // 1…6 visible peaks

// Processed data (apply to any style)
config.processedData = false       // true = enhanced pipeline

// Custom sizing
config.dotRadius = 8               // analog dots
config.barWidth = 3                // digital bars

// Bloom
config.bloomFilter = SMBloomFilter(intensity: 0.5, threshold: 0.3, radius: 12)

view.configuration = config
```

### Circle Mirror — symmetric display

When `circleMirror > 0` and style is `.circle` or `.circleLine`, the spectrum is mirrored and processed:

```
[lowFreq...highFreq] → mirror → [lowFreq...highFreq...lowFreq]
  ↓
Normalize by smoothed global max → detect peaks → build cosine hills → Tukey seam taper
```

| Parameter | Range | Description |
| --------- | ----- | ----------- |
| `circleMirror` | 0…1 | Taper fraction at seam (0.4 = 20% each end) |
| `circleMirrorPhase` | 0…1 | Rotate spectrum around the ring |
| `circleMirrorPeaks` | 1…6 | Max visible peaks |

### Processed Data Toggle

`processedData: Bool` applies the peak detection + envelope + taper pipeline to **any style**, not just circles. Turn it on to transform raw FFT data into enhanced, animation-ready magnitudes.

### Timeline Ring

```swift
// Built-in circular progress indicator
view.timelineProgress = 0.45  // 45% through the song

// Change color
view.timelineColor = UIColor.white.withAlphaComponent(0.6).cgColor
```

When using `SMAudioSpectrumDriver` with a `.file` source, progress is tracked automatically via `AVAudioPlayerNode`:

```swift
driver.onPlaybackProgress = { progress in
    view.timelineProgress = CGFloat(progress)
}
```

## Layers

Pass an array of `SMLayer` to slice the path into independent segments:

```swift
let twoPi = CGFloat.pi * 2
config.layers = [
    SMLayer(range: 0...(twoPi * 0.5),    gradient: .warmSunset,  thickness: 2),
    SMLayer(range: (twoPi * 0.5)...twoPi, gradient: .cyanMagenta, thickness: 2)
]
```

For ribbon-style displays:

```swift
config.layers = SMLayer.circleRibbon(count: 8, radialSpread: 40, phaseSpread: 0.15, gradient: .rainbow)
```

## Delegate (audio-reactive animations)

```swift
final class Coordinator: NSObject, SMSpectrumViewDelegate {
    func spectrumView(_ view: SMSpectrumView, didProduce frame: SMSpectrumFrame) {
        // frame.magnitudes, frame.timestamp, frame.bandFrequencies
    }
    func spectrumView(_ view: SMSpectrumView, didUpdateBassLevel level: Float) {
        // 0…1 — drive album art pulse
        albumArtView.transform = CGAffineTransform(scaleX: 1 + CGFloat(level) * 0.1,
                                                    y: 1 + CGFloat(level) * 0.1)
    }
    func spectrumView(_ view: SMSpectrumView, didUpdateSpectrum bass: Float, mid: Float, treble: Float) {
        // Three-band energy for richer animations
    }
    func spectrumView(_ view: SMSpectrumView, didFailWith error: SMError) {}
}
view.spectrumDelegate = coordinator
```

## Architecture

```
SMSpectrum (public API + audio + style)
    └── depends on ──▶ SMSpectrumRenderer (Metal-only)
```

## License

MIT — see [LICENSE](LICENSE).
