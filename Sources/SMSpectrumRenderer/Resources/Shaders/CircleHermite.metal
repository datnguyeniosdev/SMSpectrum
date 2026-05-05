#include <metal_stdlib>
using namespace metal;

constant int TESS_PER_BAND = 8;

struct LayerUniforms {
    float2 viewportSize;
    float  time;
    float  baseRadius;
    float  maxHeight;

    float  startAngle;
    float  endAngle;

    float  angularPhase;

    float  softness;
    float  phase;

    int    bandCount;
    int    stopCount;
    int    dynamicPhase;

    float  _padding;
};

struct VertexOut {
    float4 position [[position]];

    float  bandT;
    float  radialT;
    float  magnitude;
};

static int wrapIndex(int i, int n) {
    return ((i % n) + n) % n;
}

static float catmullRom(
    float p0,
    float p1,
    float p2,
    float p3,
    float t
) {
    float t2 = t * t;
    float t3 = t2 * t;

    return 0.5 * (
        (2.0 * p1) +
        (-p0 + p2) * t +
        (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
        (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    );
}
static float sampleMagnitude(
    device const float *mags,
    int count,
    float bandFloat
) {
    int i0 =
        clamp(
            int(floor(bandFloat)),
            0,
            count - 1
        );

    int i1 =
        min(i0 + 1, count - 1);

    float t =
        fract(bandFloat);

    // smooth cubic interpolation
    t = t * t * (3.0 - 2.0 * t);

    float v =
        mix(
            mags[i0],
            mags[i1],
            t
        );

    // noise gate
    if (v < 0.05) {
        v = 0.0;
    }

    // softer peak curve
    v = pow(v, 1.25);

    return clamp(v, 0.0, 1.0);
}

static float4 sampleGradient(
    constant float4 *stops,
    int stopCount,
    float t,
    float phase
) {
    if (stopCount <= 0) {
        return float4(1.0);
    }

    float position =
        fract(t + phase);

    float scaled =
        position * float(stopCount - 1);

    int lo =
        int(floor(scaled));

    int hi =
        min(lo + 1, stopCount - 1);

    float frac =
        scaled - float(lo);

    return mix(
        stops[lo],
        stops[hi],
        frac
    );
}

vertex VertexOut circleHermiteVertex(
    uint vertexID [[vertex_id]],
    device const float *magnitudes [[buffer(0)]],
    constant LayerUniforms &u [[buffer(1)]]
) {
    VertexOut out;

    int totalSamples =
        max(u.bandCount * TESS_PER_BAND, 8);

    int sampleIdx =
        int(vertexID) >> 1;

    int side =
        int(vertexID & 1u);

    // IMPORTANT
    float s =
        float(sampleIdx) /
        float(totalSamples);

    float arcLen =
        u.endAngle - u.startAngle;

    float angle =
        u.startAngle +
        arcLen * s +
        u.angularPhase;

    int n =
        max(u.bandCount, 1);

    // IMPORTANT
    float bandFloat = s * float(n);
     
    float magnitude =
        sampleMagnitude(
            magnitudes,
            n,
            bandFloat
        );

    magnitude =
        clamp(magnitude, 0.0, 1.0);

    // outer radius
    float outerRadius =
        u.baseRadius +
        magnitude * u.maxHeight;

    // inner radius
    float innerRadius =
        u.baseRadius;

    float radius =
        (side == 0)
        ? outerRadius
        : innerRadius;

    float2 outward =
        float2(
            cos(angle),
            sin(angle)
        );

    float2 center =
        u.viewportSize * 0.5;

    float2 pixel =
        center +
        outward * radius;

    float2 ndc =
        pixel / u.viewportSize * 2.0 - 1.0;

    ndc.y = -ndc.y;

    out.position =
        float4(ndc, 0.0, 1.0);

    out.bandT =
        s;

    out.radialT =
        (side == 0)
        ? 1.0
        : 0.15;
    
    out.magnitude =
        magnitude;

    return out;
}

fragment float4 circleHermiteFragment(
    VertexOut in [[stage_in]],
    constant float4 *stops [[buffer(0)]],
    constant LayerUniforms &u [[buffer(1)]]
) {
    float4 color =
        sampleGradient(
            stops,
            u.stopCount,
            in.bandT,
            u.phase
        );

    // softer alpha
    float fade =
        smoothstep(
            0.15,
            1.0,
            in.radialT
        );
    
    color.a *= fade;

    // glow
    float glow =
        pow(in.magnitude, 2.0) * 0.35;

    color.rgb += glow;

    return color;
}
