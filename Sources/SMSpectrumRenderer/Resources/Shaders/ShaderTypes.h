#ifndef SMSpectrumShaderTypes_h
#define SMSpectrumShaderTypes_h

// Reference declarations for shader-side types.
//
// NOTE: SwiftPM does not currently propagate header search paths into the
// .metal compiler invocation, so each .metal file declares its own copy of
// these structs. Keep this header in sync with both the .metal files and the
// `SpectrumUniforms` Swift struct in `Pipelines/SpectrumPipeline.swift`.
//
// Layout reference:
//
//   struct Uniforms {
//       float2 viewportSize;
//       float  time;
//       float  maxHeight;
//       float  thickness;
//       float  softness;
//       float  phase;
//       int    sideMode;       // 0 = A, 1 = B, 2 = both
//       int    bandCount;
//       int    stopCount;
//       int    dynamicPhase;   // bool as int32
//       float2 _padding;
//   };

#endif /* SMSpectrumShaderTypes_h */
