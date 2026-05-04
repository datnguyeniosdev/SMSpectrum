# SMSpectrum

A high-performance audio spectrum visualization SDK for iOS, inspired by Adobe After Effects' Audio Spectrum effect. Powered by Metal and Accelerate.

> Status: **v1.0 in development** — realtime audio visualization. v2.0 will add offline video export.

## Features

- Three render styles: digital bars, analog lines, analog dots
- Multiple audio sources: file, microphone, `AVAudioEngine` tap, raw PCM buffer
- Configurable frequency range, band count, smoothing, color gradient, path layout
- Metal-powered renderer at 60/120 Hz with triple buffering
- Real-time DSP via `Accelerate.vDSP`
- Modular architecture: `SMSpectrumRenderer` is independent of `SMSpectrum` audio layer

## Requirements

- iOS 13.0+
- Xcode 13+ / Swift 5.5+
- Apple GPU family 3+ (iPhone 6s and newer)

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/darrennguyen/SMSpectrum.git", from: "1.0.0")
]
```

### CocoaPods

```ruby
pod 'SMSpectrum', '~> 1.0'
```

### XCFramework

Pre-built binaries available in [Releases](https://github.com/darrennguyen/SMSpectrum/releases).

## Quick Start

```swift
import SMSpectrum

let view = SMSpectrumView(frame: .zero)
view.source = .microphone
view.configuration = .digital
view.start()
```

See `Example/SMSpectrumExample` for a full SwiftUI demo.

## Architecture

```
SMSpectrum (public API + audio + style)
    └── depends on ──▶ SMSpectrumRenderer (Metal-only)
```

`SMSpectrumRenderer` knows nothing about audio — it consumes pre-computed `RenderFrame` data. This separation enables v2 video export without coupling.

## License

MIT — see [LICENSE](LICENSE).
