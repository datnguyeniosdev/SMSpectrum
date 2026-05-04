#include <metal_stdlib>
using namespace metal;

// Tessellation density (samples per band) is supplied per-frame via
// `LayerUniforms.segmentsPerBand`, kept in sync with
// `CircleHermitePipeline.segmentsPerBand` on the Swift side.

struct LayerUniforms {
    float2 viewportSize;
    float  time;
    float  baseRadius;        // includes per-layer radialOffset
    float  maxHeight;
    float  startAngle;
    float  endAngle;
    float  angularPhase;      // shifts the spectrum within the layer
    float  thickness;
    float  softness;
    float  phase;
    int    bandCount;
    int    stopCount;
    int    segmentsPerBand;
    int    dynamicPhase;
    float  _padding;
};

struct VertexOut {
    float4 position [[position]];
    float  bandT;
    float  sideT;
    float  magnitude;
};

static float wrapMagnitude(device const float *mags, int i, int n) {
    int idx = ((i % n) + n) % n;
    return mags[idx];
}

static float hermiteValue(float p0, float p1, float t0, float t1, float t) {
    float t2 = t * t;
    float t3 = t2 * t;
    float h00 =  2.0 * t3 - 3.0 * t2 + 1.0;
    float h10 =        t3 - 2.0 * t2 + t;
    float h01 = -2.0 * t3 + 3.0 * t2;
    float h11 =        t3 -       t2;
    return h00 * p0 + h10 * t0 + h01 * p1 + h11 * t1;
}

static float hermiteDerivative(float p0, float p1, float t0, float t1, float t) {
    float t2 = t * t;
    float dh00 =  6.0 * t2 - 6.0 * t;
    float dh10 =  3.0 * t2 - 4.0 * t + 1.0;
    float dh01 = -6.0 * t2 + 6.0 * t;
    float dh11 =  3.0 * t2 - 2.0 * t;
    return dh00 * p0 + dh10 * t0 + dh01 * p1 + dh11 * t1;
}

static float4 sampleGradient(constant float4 *stops, int stopCount, float t, float phase) {
    if (stopCount <= 0) {
        return float4(1.0);
    }
    float position = clamp(t + phase - floor(t + phase), 0.0, 1.0);
    float scaled = position * float(stopCount - 1);
    int lo = int(floor(scaled));
    int hi = min(lo + 1, stopCount - 1);
    float frac = scaled - float(lo);
    return mix(stops[lo], stops[hi], frac);
}

// Cubic Hermite arc on the shared radial budget [baseRadius, baseRadius+maxHeight].
// Each layer compresses the entire spectrum (band 0 → band N-1 → wraps back
// to band 0) into its arc — so a half-arc layer shows the full spectrum on
// half a circle. Full-circle arcs close C1-continuously thanks to wrapped
// band indexing.
vertex VertexOut circleHermiteVertex(uint vertexID [[vertex_id]],
                                     device const float *magnitudes [[buffer(0)]],
                                     constant LayerUniforms &u [[buffer(1)]]) {
    int totalSamples = max(u.bandCount * u.segmentsPerBand, 1);
    int sampleIdx = int(vertexID) >> 1;
    int side = int(vertexID & 1u);

    float s = float(sampleIdx) / float(totalSamples);
    float angle = mix(u.startAngle, u.endAngle, s);

    int n = u.bandCount;

    // Spectrum compressed into the layer's arc (option (2a)). With the phase
    // shift `angularPhase` applied as a position along the arc, ribbon stacks
    // get their woven look.
    float arcLen = max(u.endAngle - u.startAngle, 1e-4);
    float phaseOffset = u.angularPhase / arcLen;
    float bandFloat = (s - phaseOffset) * float(n);

    int bandIdx = int(floor(bandFloat));
    bandIdx = ((bandIdx % n) + n) % n;
    float t = bandFloat - floor(bandFloat);

    float m_prev = wrapMagnitude(magnitudes, bandIdx - 1, n);
    float m0     = wrapMagnitude(magnitudes, bandIdx,     n);
    float m1     = wrapMagnitude(magnitudes, bandIdx + 1, n);
    float m2     = wrapMagnitude(magnitudes, bandIdx + 2, n);

    float tan0 = 0.5 * (m1 - m_prev);
    float tan1 = 0.5 * (m2 - m0);

    float magnitude = clamp(hermiteValue(m0, m1, tan0, tan1, t), 0.0, 1.0);
    float dmag_dt   = hermiteDerivative(m0, m1, tan0, tan1, t);

    float radius = u.baseRadius + magnitude * u.maxHeight;

    float dangle_ds = arcLen;
    float dt_ds     = float(n);
    float dr_ds     = dmag_dt * dt_ds * u.maxHeight;

    float2 outward = float2(cos(angle), sin(angle));
    float2 along   = float2(-sin(angle), cos(angle));

    float2 dpos_ds = dr_ds * outward + radius * along * dangle_ds;
    float len = max(length(dpos_ds), 1e-3);
    float2 normal = float2(dpos_ds.y, -dpos_ds.x) / len;
    if (dot(normal, outward) < 0.0) {
        normal = -normal;
    }

    float2 center = u.viewportSize * 0.5;
    float2 base = center + outward * radius;

    float halfThickness = max(u.thickness, 0.5) * 0.5;
    float sideT = (float(side) - 0.5) * 2.0;
    float2 pixel = base + normal * (sideT * halfThickness);

    float2 ndc = pixel / u.viewportSize * 2.0 - 1.0;
    ndc.y = -ndc.y;

    VertexOut out;
    out.position  = float4(ndc, 0.0, 1.0);
    out.bandT     = s;
    out.sideT     = sideT;
    out.magnitude = magnitude;
    return out;
}

fragment float4 circleHermiteFragment(VertexOut in [[stage_in]],
                                      constant float4 *stops [[buffer(0)]],
                                      constant LayerUniforms &u [[buffer(1)]]) {
    float4 color = sampleGradient(stops, u.stopCount, in.bandT, u.phase);

    float edge = clamp(u.softness, 0.0, 1.0);
    float distFromCenter = abs(in.sideT);
    float alpha = mix(1.0, smoothstep(1.0, max(0.0, 1.0 - edge), distFromCenter), edge);
    color.a *= alpha;

    color.rgb += in.magnitude * 0.15;
    return color;
}
