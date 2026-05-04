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
    float  rangeStart;       // start angle (radians)
    float  rangeEnd;         // end angle (radians)
    float  layerThickness;
    float  _padding;
};

struct VertexOut {
    float4 position [[position]];
    float  bandT;     // 0...1 across bands inside the layer
    float  lengthT;   // 0 at base, 1 at tip
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

// AE-style audio spectrum on a circular path: each frequency band is a
// discrete radial wedge tiled around the layer's arc. Wedges share their
// base radius so collectively they form a closed ring even at silence.
// `rangeStart`/`rangeEnd` constrain the arc; the full spectrum is laid out
// across that arc (one band per instance).
vertex VertexOut circleBarVertex(uint vertexID [[vertex_id]],
                                 uint instanceID [[instance_id]],
                                 device const float *magnitudes [[buffer(0)]],
                                 constant Uniforms &u [[buffer(1)]]) {
    float2 quad = float2(float(vertexID & 1u), float((vertexID >> 1u) & 1u));

    float arcLen = u.rangeEnd - u.rangeStart;
    float arcWidth = arcLen / float(u.bandCount);
    float baseAngle = u.rangeStart + (float(instanceID) + 0.5) * arcWidth;
    float fillFactor = clamp(1.0 - u.barSpacing, 0.05, 1.0);
    float angle = baseAngle + (quad.x - 0.5) * arcWidth * fillFactor;

    float2 outward = float2(cos(angle), sin(angle));
    float2 center = u.viewportSize * 0.5;
    float baseRadius = min(u.viewportSize.x, u.viewportSize.y) * 0.25;

    float magnitude = clamp(magnitudes[instanceID], 0.0, 1.0);

    float stem = max(u.layerThickness, 1.0);
    float lineLength = stem + magnitude * u.maxHeight;

    float radius = baseRadius + quad.y * lineLength;
    float2 pixel = center + outward * radius;
    float2 ndc = pixel / u.viewportSize * 2.0 - 1.0;
    ndc.y = -ndc.y;

    VertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.bandT = float(instanceID) / max(float(u.bandCount - 1), 1.0);
    out.lengthT = quad.y;
    out.magnitude = magnitude;
    return out;
}

fragment float4 circleBarFragment(VertexOut in [[stage_in]],
                                  constant float4 *stops [[buffer(0)]],
                                  constant Uniforms &u [[buffer(1)]]) {
    float4 color = sampleGradient(stops, u.stopCount, in.bandT, u.phase);

    float fadeMix = clamp(u.softness, 0.0, 1.0);
    float fade = mix(1.0, in.lengthT, fadeMix);
    color.a *= fade;

    float tipBoost = smoothstep(0.85, 1.0, in.lengthT) * in.magnitude * 0.4;
    color.rgb += tipBoost;
    return color;
}
