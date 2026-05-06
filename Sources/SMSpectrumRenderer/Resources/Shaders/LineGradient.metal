#include <metal_stdlib>
using namespace metal;

constant int TESS_PER_BAND = 6;

struct Uniforms {
    float2 viewportSize;
    float  time;
    float  maxHeight;
    float  thickness;
    float  softness;
    float  phase;
    float  barSpacing;
    int    sideMode;
    int    bandCount;
    int    stopCount;
    int    dynamicPhase;
    float  rangeStart;
    float  rangeEnd;
    float  layerThickness;
    int    orientation;       // 0 = horizontal, 1 = vertical
};

struct VertexOut {
    float4 position [[position]];
    float  bandT;
    float  verticalT;
    float  magnitude;
};

static float catmullRom(float p0, float p1, float p2, float p3, float t) {
    float t2 = t * t;
    float t3 = t2 * t;
    return 0.5 * (
        (2.0 * p1) +
        (-p0 + p2) * t +
        (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
        (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    );
}

static float sampleSmoothMagnitude(device const float *mags, int bandCount, float bandFloat) {
    int i1 = clamp(int(floor(bandFloat)), 0, bandCount - 1);
    int i0 = max(0, i1 - 1);
    int i2 = min(bandCount - 1, i1 + 1);
    int i3 = min(bandCount - 1, i1 + 2);
    float t = bandFloat - float(i1);
    float v = catmullRom(mags[i0], mags[i1], mags[i2], mags[i3], t);
    return clamp(v, 0.0, 1.0);
}

static float4 sampleGradient(constant float4 *stops, int stopCount, float t, float phase) {
    if (stopCount <= 0) {
        return float4(1.0);
    }
    float position = fract(t + phase);
    float scaled = position * float(stopCount - 1);
    int lo = int(floor(scaled));
    int hi = min(lo + 1, stopCount - 1);
    float frac = scaled - float(lo);
    return mix(stops[lo], stops[hi], frac);
}

vertex VertexOut lineGradientVertex(uint vertexID [[vertex_id]],
                                    device const float *magnitudes [[buffer(0)]],
                                    constant Uniforms &u [[buffer(1)]]) {
    uint sampleIndex = vertexID >> 1u;
    bool isTop = (vertexID & 1u) == 0u;

    int totalSamples = max(u.bandCount * TESS_PER_BAND, 1);
    float bandT = float(sampleIndex) / float(totalSamples - 1);
    float bandFloat = bandT * float(u.bandCount - 1);
    float magnitude = sampleSmoothMagnitude(magnitudes, u.bandCount, bandFloat);
    float displacement = magnitude * u.maxHeight;

    bool isVertical = (u.orientation == 1);
    float bandAxisLen   = isVertical ? u.viewportSize.y : u.viewportSize.x;
    float extendAxisLen = isVertical ? u.viewportSize.x : u.viewportSize.y;
    float baseline = extendAxisLen * 0.5;
    float dirSign = isVertical ? +1.0 : -1.0;

    // `.both` is encoded by the pipeline as two draw calls (mode 0 + 1).
    float topCoord = (u.sideMode == 1)
        ? baseline - dirSign * displacement
        : baseline + dirSign * displacement;

    float layerSpan = u.rangeEnd - u.rangeStart;
    float bandPixel = (u.rangeStart + bandT * layerSpan) * bandAxisLen;
    float extendPixel = isTop ? topCoord : baseline;

    float2 pixel = isVertical
        ? float2(extendPixel, bandPixel)
        : float2(bandPixel, extendPixel);

    float2 ndc = pixel / u.viewportSize * 2.0 - 1.0;
    ndc.y = -ndc.y;

    VertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.bandT = bandT;
    out.verticalT = isTop ? 1.0 : 0.0;
    out.magnitude = magnitude;
    return out;
}

fragment float4 lineGradientFragment(VertexOut in [[stage_in]],
                                     constant float4 *stops [[buffer(0)]],
                                     constant Uniforms &u [[buffer(1)]]) {
    float4 color = sampleGradient(stops, u.stopCount, in.bandT, u.phase);
    float fade = pow(in.verticalT, max(u.softness * 2.0, 0.0001) + 0.5);
    color.a *= fade;
    return color;
}
