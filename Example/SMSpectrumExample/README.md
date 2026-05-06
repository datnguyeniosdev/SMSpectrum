# SMSpectrumExample

A SwiftUI demonstration app for the `SMSpectrum` SDK.

## Generating the Xcode project

This example uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to keep the
Xcode project in sync with `project.yml`. The generated `.xcodeproj` is
git-ignored.

```bash
brew install xcodegen      # one-time
cd Example/SMSpectrumExample
xcodegen generate
open SMSpectrumExample.xcodeproj
```

## Demo screens

- **Microphone** — realtime live input with style switcher.
- **Audio File** — bundled track playback driving the visualization.
- **Configuration** — interactive panel binding to `SMConfiguration`.
