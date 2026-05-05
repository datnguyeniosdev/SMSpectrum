# SMSpectrum

A high-performance audio spectrum visualization SDK for iOS, inspired by Adobe After Effects' Audio Spectrum effect. Powered by Metal and Accelerate.

> Status: **v1.0 in development** — realtime audio visualization. v2.0 will add offline video export.

## Features

- Six render styles: digital bars, analog lines, analog dots, radial bars, smooth Cubic Hermite ring, line gradient, time-domain waveform
- Multiple audio sources: file playback, microphone, external `AVAudioEngine` tap, manual PCM push
- Bring-your-own-data path: feed pre-computed magnitudes directly (network feed, simulation, custom DSP)
- Configurable frequency range, band count, FFT size, attack/release smoothing, color gradient, geometric path
- Multi-layer rendering — slice the path into segments, each with its own gradient and thickness
- Horizontal or vertical orientation for line-based styles, with one-sided or mirrored side modes
- Optional post-process bloom (separable gaussian, half-resolution) — works with every style
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
    .package(url: "https://github.com/darrennguyen/SMSpectrum.git", from: "1.0.0")
]
```

The package vends two products:

- `SMSpectrum` — full SDK (view + audio engine + DSP). Most apps want this.
- `SMSpectrumRenderer` — Metal renderer only. Pull this in if you have your own audio pipeline and just want the GPU drawing.

### CocoaPods

```ruby
pod 'SMSpectrum', '~> 1.0'         # Core (default subspec — pulls in Renderer)
pod 'SMSpectrum/Renderer', '~> 1.0' # Renderer only
```

### XCFramework

Pre-built binaries available in [Releases](https://github.com/darrennguyen/SMSpectrum/releases).

## Quick Start

```swift
import SMSpectrum

let view = try SMSpectrumView(configuration: .digital)
let driver = SMAudioSpectrumDriver(configuration: .digital)
driver.attach(to: view)
try driver.start(source: .microphone)
```

That's it — `SMSpectrumView` is a `MTKView` subclass, add it to your view hierarchy and it draws automatically. See `Example/SMSpectrumExample` for a full SwiftUI demo.

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
- `.audioEngine(AVAudioEngine, node: AVAudioNode)` — taps an existing engine, useful when audio is already running for another purpose
- `.manual` — you push PCM buffers via `driver.push(pcmBuffer:sampleRate:time:)`

### 2. Bring-your-own data (no audio engine)

Skip the driver entirely and push frames yourself — useful for network-streamed magnitudes, music game simulations, or custom DSP:

```swift
let view = try SMSpectrumView(configuration: .digital)

// One-time: figure out the Hz layout if you care which slot is which.
let frequencies = view.configuration.bandCenterFrequencies(sampleRate: 48_000)

// Per frame: push 0...1 magnitudes. Length should equal bandCount;
// mismatched lengths are treated as raw FFT half-bins and remapped.
view.push(magnitudes: myMagnitudes)
```

`push(magnitudes:)` is thread-safe. Smoothing (`SMConfiguration.smoothing` and `bandSmoothing`) is applied internally before rendering.

### 3. Renderer-only (no `SMSpectrumView`, no audio)

For exotic cases — offscreen rendering, custom view hierarchies, or video export — depend on `SMSpectrumRenderer` directly and feed it `RenderFrame` values:

```swift
import SMSpectrumRenderer

let renderer = try SpectrumRenderer()
renderer.attach(to: myMTKView)

let frame = RenderFrame(
    magnitudes: myMagnitudes,
    timestamp: CACurrentMediaTime(),
    style: myDescriptor
)
try renderer.render(frame: frame, drawable: drawable, renderPassDescriptor: pass, viewportSize: size)
```

The renderer is fully audio-agnostic — this is the seam that v2.0's video exporter will reuse.

## Configuration

`SMConfiguration` is the single source of truth for visual style. Built-in presets cover most cases:

| Preset             | Style          | Notes                                                     |
| ------------------ | -------------- | --------------------------------------------------------- |
| `.digital`         | digital bars   | Highest performance, classic VU look                      |
| `.analogLines`     | polyline       | Smooth continuous curve with softness/glow                |
| `.analogDots`      | dots           | One dot per band                                          |
| `.circle`          | radial bars    | Bars radiating outward from a circle                      |
| `.circleHermite`   | filled ring    | Donut sector fill — alpha fades inward from the curve     |
| `.circleWaveform`  | filled ring    | Snappier filled ring — sharp transients travel around     |
| `.lineGradient`    | filled area    | Filled area under curve, horizontal hue + vertical fade   |
| `.waveform`        | flat waveform  | Thin solid line with sharp transient peaks                |

Customize any preset by mutating its fields:

```swift
var config = SMConfiguration.digital
config.frequencyRange = 60...12_000
config.bandCount = 64
config.gradient = .rainbow
config.smoothing = .silky          // .snappy / .balanced / .smooth / .silky
config.bandSmoothing = 0.5         // 0...1, extra spatial blur across bands
view.configuration = config
```

Key fields:

- `style` — visual style enum (see Styles below)
- `frequencyRange` — Hz min...max for log-band layout, default `20...20_000`
- `bandCount` — 8...1024, default 96
- `fftSize` — `.size512` / `.size1024` / `.size2048` / `.size4096`. Larger = finer frequency resolution, more latency
- `maxHeight` — peak height in points
- `thickness` — bar / line / dot size in points
- `softness` — 0...1, edge feather for analog styles
- `path` — geometric layout (`.line` / `.circle` / `.custom(CGPath)`)
- `gradient` — color sweep along the band axis (`.cyanMagenta`, `.warmSunset`, `.rainbow`, or custom)
- `sideMode` — `.sideA` / `.sideB` / `.both` (mirrored)
- `smoothing` — attack/release time constants (`.snappy` / `.balanced` / `.smooth` / `.silky`)
- `barSpacing` — 0...1 fractional gap between bars (circle bars only)
- `circleMode` — `.bars` or `.cubicHermite` for the `.circle` style
- `circleBaseRadius` — inner ring radius for `.circleHermite`
- `layers` — multi-layer rendering (see below)
- `bloomFilter` — optional post-process bloom (see Bloom below)
- `orientation` — `.horizontal` (default) or `.vertical` for line-based styles (see Orientation below)

## Layers

By default a configuration draws the path once with the config-level gradient and thickness. Pass an array of `SMLayer` to slice the path into independent segments, each with its own gradient, thickness, and (for `.circleHermite`) radial offset / angular phase.

`range` is interpreted by the active style:

- **`.circle`**: angles in radians (CCW from +X). `0...(2π)` is a full ring.
- **All other styles**: normalized position along the path, `0...1`.

```swift
let twoPi = CGFloat.pi * 2
config.layers = [
    SMLayer(range: 0...(twoPi * 0.5),    gradient: .warmSunset,  thickness: 2),
    SMLayer(range: (twoPi * 0.5)...twoPi, gradient: .cyanMagenta, thickness: 2)
]
```

For ribbon-style `.circleHermite` displays, use the convenience builder:

```swift
config.layers = SMLayer.circleRibbon(
    count: 8,
    radialSpread: 40,
    phaseSpread: 0.15,
    gradient: .rainbow
)
```

> **Note**: `.circleHermite` renders as a **filled donut sector** — `SMLayer.thickness` is ignored. The fill spans `circleBaseRadius` (inner) to `circleBaseRadius + magnitude * maxHeight` (outer); alpha is full at the outer edge and fades inward, controlled by `softness`.

## Orientation

`SMConfiguration.orientation` rotates the band axis 90° for line-based styles (`.digital`, `.analogLines`, `.analogDots`, `.lineGradient`, `.waveform`). Circle styles ignore it.

| Orientation     | Bands run    | Bars extend       | `sideMode` mapping            |
| --------------- | ------------ | ----------------- | ----------------------------- |
| `.horizontal`   | left → right | up / down         | `.sideA` = top, `.sideB` = bottom, `.both` = mirrored |
| `.vertical`     | top → bottom | right / left      | `.sideA` = right, `.sideB` = left, `.both` = mirrored |

```swift
var config = SMConfiguration.digital
config.orientation = .vertical
config.sideMode = .sideA      // bars extend to the right only
view.configuration = config
```

## Bloom

`SMConfiguration.bloomFilter` enables a post-process bloom that runs after the spectrum is drawn. The renderer renders into an offscreen texture, isolates pixels above `threshold`, gaussian-blurs them at half resolution, and composites the result into the drawable. It is style-agnostic — every render style benefits.

```swift
var config = SMConfiguration.circleHermite
config.bloomFilter = SMBloomFilter(intensity: 0.8, threshold: 0.4, radius: 14)
view.configuration = config
```

Built-in presets: `.soft`, `.neon`, `.dreamy`. Set `bloomFilter = nil` to disable (default).

Knobs:

- `intensity` — strength of the blurred bright pass (0 = invisible, 1 = standard, > 1 = overdrive)
- `threshold` — luminance cutoff (0...1); only pixels brighter than this contribute
- `radius` — blur radius in points; larger values produce softer, wider bloom

## Delegate callbacks

```swift
final class Coordinator: NSObject, SMSpectrumViewDelegate {
    func spectrumView(_ view: SMSpectrumView, didProduce frame: SMSpectrumFrame) {
        // frame.magnitudes        — 0...1 per band
        // frame.timestamp         — seconds
        // frame.bandFrequencies   — Hz per band
    }
    func spectrumView(_ view: SMSpectrumView, didFailWith error: SMError) {
        // Renderer or audio engine errors. Main thread.
    }
}
view.spectrumDelegate = coordinator
```

Useful for syncing animations to the audio, recording analysis output, or driving secondary UI.

## Architecture

```
SMSpectrum (public API + audio + style)
    └── depends on ──▶ SMSpectrumRenderer (Metal-only)
```

`SMSpectrumRenderer` knows nothing about audio — it consumes pre-computed `RenderFrame` data containing magnitudes + a `RenderStyleDescriptor`. The `SMSpectrum` layer adds:

- `SMAudioSpectrumDriver` — `AVAudioEngine` capture + `vDSP` FFT + log-band mapping
- `SMSpectrumView` — `MTKView` wrapper that owns a `SpectrumRenderer` and applies smoothing
- Public Swift-friendly types (`SMConfiguration`, `SMStyle`, `SMSource`, `SMColorGradient`, etc.)

This separation enables v2.0's video export without coupling the renderer to a realtime audio path.

### Threading

- `SMSpectrumView.push(magnitudes:)` and `push(frame:)` are safe from any thread.
- `SMAudioSpectrumDriver.onFrame` fires on a background thread — dispatch to main yourself if your handler touches UI.
- `onError` and the view delegate methods are called on the main thread.

## License

MIT — see [LICENSE](LICENSE).
