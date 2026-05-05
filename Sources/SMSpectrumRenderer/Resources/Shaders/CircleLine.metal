#include <metal_stdlib>
using namespace metal;

// ============================================================
//  Circle Line — circular stroke trace (no fill).
//  Draws a thick line along the outer edge of the magnitude
//  curve around a ring. Uses wrapped Catmull-Rom interpolation
//  for a smooth closed curve, gradient sampled along the arc,
//  and alpha feathering at the stroke edges.
// ============================================================

constant int TESS_PER_BAND = 6;

struct Uniforms {
    float2 viewportSize;
    float  time;
    float  baseRadius;
    float  maxHeight;
    float  startAngle;
    float  endAngle;
    float  softness;
    float  phase;
    int    bandCount;
    int    stopCount;
    int    dynamicPhase;
    float  layerThickness;
};

struct VertexOut {
    float4 position [[position]];
    float  side;       // -1 or +1 from line center
    float  bandT;      // 0...1 (drives gradient)
    float  magnitude;
};

static int wrapIndex(int i, int n) {
    return ((i % n) + n) % n;
}

static float catmullRomWrapped(device const float *mags,
                                int bandCount,
                                float bandFloat) {
    int i1 = wrapIndex(int(floor(bandFloat)), bandCount);
    int i0 = wrapIndex(i1 - 1, bandCount);
    int i2 = wrapIndex(i1 + 1, bandCount);
    int i3 = wrapIndex(i1 + 2, bandCount);
    float t = bandFloat - floor(bandFloat);
    float t2 = t * t;
    float t3 = t2 * t;
    float v = 0.5 * (
        (2.0 * mags[i1]) +
        (-mags[i0] + mags[i2]) * t +
        (2.0 * mags[i0] - 5.0 * mags[i1] + 4.0 * mags[i2] - mags[i3]) * t2 +
        (-mags[i0] + 3.0 * mags[i1] - 3.0 * mags[i2] + mags[i3]) * t3
    );
    return clamp(v, 0.0, 1.0);
}

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

vertex VertexOut circleLineVertex(uint vertexID [[vertex_id]],
                                  device const float *magnitudes [[buffer(0)]],
                                  constant Uniforms &u [[buffer(1)]]) {
    int totalSamples = max(u.bandCount * TESS_PER_BAND, 3);
    int sampleIdx = int(vertexID) >> 1;
    float sideDir = (vertexID & 1u) == 0u ? -1.0 : 1.0;

    float s = float(sampleIdx) / float(totalSamples);
    float arcLen = max(u.endAngle - u.startAngle, 1e-4);
    float angle = u.startAngle + arcLen * s;

    int n = max(u.bandCount, 1);
    float bandFloat = s * float(n);
    float magnitude = catmullRomWrapped(magnitudes, n, bandFloat);

    float radius = u.baseRadius + magnitude * u.maxHeight;
    float2 outward = float2(cos(angle), sin(angle));
    float2 tangent = float2(-sin(angle), cos(angle));

    float halfThick = max(u.layerThickness, 1.0) * 0.5;
    float2 center = u.viewportSize * 0.5;
    float2 pixel = center + outward * radius + tangent * sideDir * halfThick;

    float2 ndc = pixel / u.viewportSize * 2.0 - 1.0;
    ndc.y = -ndc.y;

    VertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.side = sideDir;
    out.bandT = s;
    out.magnitude = magnitude;
    return out;
}

fragment float4 circleLineFragment(VertexOut in [[stage_in]],
                                   constant float4 *stops [[buffer(0)]],
                                   constant Uniforms &u [[buffer(1)]]) {
    float4 color = sampleGradient(stops, u.stopCount, in.bandT, u.phase);
    float edge = max(u.softness, 1e-4);
    float alpha = smoothstep(1.0, 1.0 - edge, abs(in.side));
    color.a *= alpha;
    return color;
}
