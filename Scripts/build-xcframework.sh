#!/usr/bin/env bash
# Build XCFramework for SMSpectrum and SMSpectrumRenderer.
# Output: Output/SMSpectrum.xcframework, Output/SMSpectrumRenderer.xcframework

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/Output"
ARCHIVE_DIR="${OUTPUT_DIR}/Archives"

SCHEMES=("SMSpectrum" "SMSpectrumRenderer")
DESTINATIONS=(
    "generic/platform=iOS"
    "generic/platform=iOS Simulator"
    "generic/platform=macOS,variant=Mac Catalyst"
)
DESTINATION_NAMES=("ios" "ios-sim" "maccatalyst")

rm -rf "${OUTPUT_DIR}"
mkdir -p "${ARCHIVE_DIR}"

for scheme in "${SCHEMES[@]}"; do
    archives=()
    for i in "${!DESTINATIONS[@]}"; do
        destination="${DESTINATIONS[$i]}"
        name="${DESTINATION_NAMES[$i]}"
        archive_path="${ARCHIVE_DIR}/${scheme}-${name}.xcarchive"
        echo "Archiving ${scheme} for ${name}..."
        xcodebuild archive \
            -scheme "${scheme}" \
            -destination "${destination}" \
            -archivePath "${archive_path}" \
            -configuration Release \
            SKIP_INSTALL=NO \
            BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
            > /dev/null
        archives+=("-archive" "${archive_path}" "-framework" "${scheme}.framework")
    done

    echo "Creating ${scheme}.xcframework..."
    xcodebuild -create-xcframework \
        "${archives[@]}" \
        -output "${OUTPUT_DIR}/${scheme}.xcframework"
done

rm -rf "${ARCHIVE_DIR}"
echo "Done. Frameworks at ${OUTPUT_DIR}"
