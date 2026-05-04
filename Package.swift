// swift-tools-version: 5.5
import PackageDescription

let package = Package(
    name: "SMSpectrum",
    platforms: [
        .iOS(.v13),
        .macCatalyst(.v13)
    ],
    products: [
        .library(
            name: "SMSpectrum",
            targets: ["SMSpectrum"]
        ),
        .library(
            name: "SMSpectrumRenderer",
            targets: ["SMSpectrumRenderer"]
        )
    ],
    targets: [
        .target(
            name: "SMSpectrumRenderer",
            path: "Sources/SMSpectrumRenderer",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "SMSpectrum",
            dependencies: ["SMSpectrumRenderer"],
            path: "Sources/SMSpectrum"
        ),
        .testTarget(
            name: "SMSpectrumRendererTests",
            dependencies: ["SMSpectrumRenderer"],
            path: "Tests/SMSpectrumRendererTests"
        ),
        .testTarget(
            name: "SMSpectrumTests",
            dependencies: ["SMSpectrum"],
            path: "Tests/SMSpectrumTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
