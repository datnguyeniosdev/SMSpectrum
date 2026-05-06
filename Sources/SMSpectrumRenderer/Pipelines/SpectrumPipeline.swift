import Foundation
import Metal

/// Tessellation factor for line-based pipelines.
///
/// The number of sample points along the spectrum is `bandCount * tessellationFactor`,
/// with smooth Catmull-Rom interpolation between original band magnitudes. Higher
/// factors produce smoother curves at modest GPU cost.
///
/// Must match the `TESS_PER_BAND` constant in the line `.metal` shaders.
let tessellationFactor: Int = 6

/// Common interface for a per-style render pipeline.
///
/// Pipelines own their `MTLRenderPipelineState` and know how to encode a
/// `RenderFrame` against a shared `BufferPool`. They do not own the command
/// buffer or encoder lifecycle — that is `SpectrumRenderer`'s responsibility.
protocol SpectrumPipeline: AnyObject {
    init(library: PipelineLibrary, pixelFormat: MTLPixelFormat) throws

    func encode(
        frame: RenderFrame,
        viewportSize: SIMD2<Float>,
        bufferPool: BufferPool,
        encoder: MTLRenderCommandEncoder
    ) throws
}

/// Uniform layout shared by all non-Hermite pipelines. Must match the
/// `Uniforms` struct declared in every `.metal` shader. 64 bytes, 8-byte aligned.
struct SpectrumUniforms {
    var viewportSize: SIMD2<Float>  //  0..8
    var time: Float                  //  8..12
    var maxHeight: Float             // 12..16
    var thickness: Float             // 16..20  (config-level fallback)
    var softness: Float              // 20..24
    var phase: Float                 // 24..28
    var barSpacing: Float            // 28..32
    var sideMode: Int32              // 32..36
    var bandCount: Int32             // 36..40
    var stopCount: Int32             // 40..44
    var dynamicPhase: Int32          // 44..48
    var rangeStart: Float            // 48..52
    var rangeEnd: Float              // 52..56
    var layerThickness: Float        // 56..60
    var orientation: Int32 = 0       // 60..64  (0 = horizontal, 1 = vertical)
}

extension SpectrumUniforms {
    /// Maps a `RenderSideMode` to its shader-side integer code.
    static func sideModeRaw(_ mode: RenderSideMode) -> Int32 {
        switch mode {
        case .sideA: return 0
        case .sideB: return 1
        case .both: return 2
        }
    }

    /// Maps a `RenderOrientation` to its shader-side integer code.
    static func orientationRaw(_ orientation: RenderOrientation) -> Int32 {
        switch orientation {
        case .horizontal: return 0
        case .vertical: return 1
        }
    }

    /// Per-draw sideMode raws for a `RenderSideMode`. `.both` expands to
    /// `[0, 1]` so pipelines issue two draws (sideA + sideB) for a true
    /// symmetric mirror, instead of asking the shader to handle "both" as
    /// a single mode.
    static func sideModeDrawRaws(_ mode: RenderSideMode) -> [Int32] {
        switch mode {
        case .sideA: return [0]
        case .sideB: return [1]
        case .both:  return [0, 1]
        }
    }
}
