#include <metal_stdlib>
using namespace metal;

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
    float2 localUV;
    float  bandT;
    float  magnitude;
};

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

vertex VertexOut analogDotVertex(uint vertexID [[vertex_id]],
                                 uint instanceID [[instance_id]],
                                 device const float *magnitudes [[buffer(0)]],
                                 constant Uniforms &u [[buffer(1)]]) {
    float2 quad = float2(float(vertexID & 1u), float((vertexID >> 1u) & 1u));
    float2 centered = quad - 0.5;

    float magnitude = clamp(magnitudes[instanceID], 0.0, 1.0);
    float bandT = float(instanceID) / max(float(u.bandCount - 1), 1.0);
    float radius = max(u.layerThickness, 1.0);
    float displacement = magnitude * u.maxHeight;

    bool isVertical = (u.orientation == 1);
    float bandAxisLen   = isVertical ? u.viewportSize.y : u.viewportSize.x;
    float extendAxisLen = isVertical ? u.viewportSize.x : u.viewportSize.y;
    float center = extendAxisLen * 0.5;
    float dirSign = isVertical ? +1.0 : -1.0;

    // `.both` is encoded by the pipeline as two draw calls (mode 0 + 1).
    float coord;
    if (u.sideMode == 1) {
        coord = center - dirSign * displacement;
    } else {
        coord = center + dirSign * displacement;
    }

    float layerSpan = u.rangeEnd - u.rangeStart;
    float bandPixel = (u.rangeStart + bandT * layerSpan) * bandAxisLen;

    float2 dotCenter = isVertical
        ? float2(coord, bandPixel)
        : float2(bandPixel, coord);

    float2 pixel = dotCenter + centered * radius * 2.0;
    float2 ndc = pixel / u.viewportSize * 2.0 - 1.0;
    ndc.y = -ndc.y;

    VertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.localUV = quad;
    out.bandT = bandT;
    out.magnitude = magnitude;
    return out;
}

fragment float4 analogDotFragment(VertexOut in [[stage_in]],
                                  constant float4 *stops [[buffer(0)]],
                                  constant Uniforms &u [[buffer(1)]]) {
    float2 centered = in.localUV - 0.5;
    float dist = length(centered) * 2.0;
    float edge = max(u.softness, 1e-4);
    float alpha = smoothstep(1.0, 1.0 - edge, dist);
    if (alpha <= 0.0) {
        discard_fragment();
    }

    float4 color = sampleGradient(stops, u.stopCount, in.bandT, u.phase);
    color.a *= alpha;
    return color;
}
