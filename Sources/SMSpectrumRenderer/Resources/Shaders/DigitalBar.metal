#include <metal_stdlib>
using namespace metal;

constant int TESS_PER_BAND = 6;

struct Uniforms {
    float2 viewportSize;
    float  time;
    float  maxHeight;
    float  thickness;        // config-level fallback (unused per-layer)
    float  softness;
    float  phase;
    float  barSpacing;
    int    sideMode;
    int    bandCount;
    int    stopCount;
    int    dynamicPhase;
    float  rangeStart;       // 0..1 fraction of viewport width where layer starts
    float  rangeEnd;         // 0..1 fraction of viewport width where layer ends
    float  layerThickness;   // per-layer stroke
    float  _padding;
};

struct VertexOut {
    float4 position [[position]];
    float  side;
    float  bandT;            // 0...1 inside the layer (drives gradient)
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

vertex VertexOut digitalBarVertex(uint vertexID [[vertex_id]],
                                  device const float *magnitudes [[buffer(0)]],
                                  constant Uniforms &u [[buffer(1)]]) {
    uint sampleIndex = vertexID >> 1u;
    float side = (vertexID & 1u) == 0u ? -1.0 : 1.0;

    int totalSamples = max(u.bandCount * TESS_PER_BAND, 1);
    float bandT = float(sampleIndex) / float(totalSamples - 1);
    float bandFloat = bandT * float(u.bandCount - 1);
    float magnitude = sampleSmoothMagnitude(magnitudes, u.bandCount, bandFloat);
    float displacement = magnitude * u.maxHeight;

    float centerY = u.viewportSize.y * 0.5;
    float lineY;
    if (u.sideMode == 0) {
        lineY = centerY - displacement;
    } else if (u.sideMode == 1) {
        lineY = centerY + displacement;
    } else {
        lineY = centerY - displacement * sign(side);
    }

    float layerWidth = u.rangeEnd - u.rangeStart;
    float pixelX = (u.rangeStart + bandT * layerWidth) * u.viewportSize.x;
    float pixelY = lineY + side * u.layerThickness * 0.5;

    float2 ndc = float2(pixelX, pixelY) / u.viewportSize * 2.0 - 1.0;
    ndc.y = -ndc.y;

    VertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.side = side;
    out.bandT = bandT;
    out.magnitude = magnitude;
    return out;
}

fragment float4 digitalBarFragment(VertexOut in [[stage_in]],
                                   constant float4 *stops [[buffer(0)]],
                                   constant Uniforms &u [[buffer(1)]]) {
    float4 color = sampleGradient(stops, u.stopCount, in.bandT, u.phase);
    float edge = max(u.softness, 1e-4);
    float alpha = smoothstep(1.0, 1.0 - edge, abs(in.side));
    color.a *= alpha;
    return color;
}
