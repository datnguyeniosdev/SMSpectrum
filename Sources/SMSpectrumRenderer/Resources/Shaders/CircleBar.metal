#include <metal_stdlib>
using namespace metal;

// ============================================================
//  Circle Bars — fixed-pixel-width rectangular bars on a ring.
//  Each band renders one rectangle oriented radially: the long
//  axis runs outward from the inner ring, the short axis is the
//  tangent (constant pixel width regardless of radius). Gradient
//  sweeps along the angular axis; alpha softly fades from the
//  outer tip toward the inner base.
// ============================================================

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
    float  _padding;
};

struct VertexOut {
    float4 position [[position]];
    float  bandT;
    float  lengthT;   // 0 = inner base, 1 = outer tip
    float  magnitude;
};

static float4 sampleGradient(constant float4 *stops,
                              int stopCount,
                              float t,
                              float phase) {
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

vertex VertexOut circleBarVertex(uint vertexID [[vertex_id]],
                                  uint instanceID [[instance_id]],
                                  device const float *magnitudes [[buffer(0)]],
                                  constant Uniforms &u [[buffer(1)]]) {
    // Quad layout: x = 0 (left tangent) / 1 (right tangent),
    //              y = 0 (inner base)    / 1 (outer tip).
    float qx = float(vertexID & 1u);
    float qy = float((vertexID >> 1u) & 1u);

    float arcLen = max(u.rangeEnd - u.rangeStart, 1e-4);
    float bandCountF = max(float(u.bandCount), 1.0);
    float bandT = (float(instanceID) + 0.5) / bandCountF;
    float angle = u.rangeStart + bandT * arcLen;

    float2 outward = float2(cos(angle), sin(angle));
    float2 tangent = float2(-sin(angle), cos(angle));

    int idx = clamp(int(instanceID), 0, u.bandCount - 1);
    float magnitude = clamp(magnitudes[idx], 0.0, 1.0);

    // Inner ring radius: 30% of the smaller viewport dimension.
    float baseRadius = min(u.viewportSize.x, u.viewportSize.y) * 0.30;
    float lineLength = magnitude * u.maxHeight;
    float radius = baseRadius + qy * lineLength;

    // Constant pixel width — the bar does NOT widen with radius.
    // Falls back through layerThickness -> config thickness -> 2pt default.
    float barWidth = u.layerThickness > 0.0
        ? u.layerThickness
        : (u.thickness > 0.0 ? u.thickness : 2.0);
    float halfWidth = barWidth * 0.5;

    float2 center = u.viewportSize * 0.5;
    float2 tangentOffset = tangent * (qx - 0.5) * 2.0 * halfWidth;
    float2 pixel = center + outward * radius + tangentOffset;

    float2 ndc = pixel / u.viewportSize * 2.0 - 1.0;
    ndc.y = -ndc.y;

    VertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.bandT = bandT;
    out.lengthT = qy;
    out.magnitude = magnitude;
    return out;
}

fragment float4 circleBarFragment(VertexOut in [[stage_in]],
                                   constant float4 *stops [[buffer(0)]],
                                   constant Uniforms &u [[buffer(1)]]) {
    float4 color = sampleGradient(stops, u.stopCount, in.bandT, u.phase);
    // Full alpha at the outer tip, fades toward the inner base — controlled
    // by softness. Higher softness => longer, gentler fade.
    float fade = pow(in.lengthT, max(u.softness * 2.0, 0.0001) + 0.5);
    color.a *= fade;
    return color;
}
