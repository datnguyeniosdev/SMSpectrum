#include <metal_stdlib>
using namespace metal;

// ============================================================
//  Post-process bloom: bright-pass -> separable gaussian -> composite.
//  Operates on a half-resolution bloom texture for cost; the final
//  composite samples scene + blurred bloom and writes to the drawable.
// ============================================================

struct FullscreenVertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex FullscreenVertexOut bloomFullscreenVertex(uint vid [[vertex_id]]) {
    // Single triangle that covers the screen. Larger than NDC by 2x in both
    // axes so the rasterizer fully covers the [-1,1] viewport.
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    FullscreenVertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = float2(positions[vid].x * 0.5 + 0.5,
                    1.0 - (positions[vid].y * 0.5 + 0.5));
    return out;
}

// ------------------------------------------------------------
// Bright pass
// ------------------------------------------------------------

struct BrightPassUniforms {
    float threshold;
};

fragment float4 bloomBrightFragment(FullscreenVertexOut in [[stage_in]],
                                     texture2d<float> sceneTexture [[texture(0)]],
                                     constant BrightPassUniforms &u [[buffer(0)]]) {
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    float4 color = sceneTexture.sample(smp, in.uv);
    float luma = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float mask = smoothstep(u.threshold, u.threshold + 0.1, luma);
    return float4(color.rgb * mask, color.a * mask);
}

// ------------------------------------------------------------
// Separable gaussian blur (9-tap)
// ------------------------------------------------------------

struct BlurUniforms {
    float2 direction;   // step in UV per tap; sign determines axis
};

fragment float4 bloomBlurFragment(FullscreenVertexOut in [[stage_in]],
                                   texture2d<float> sourceTexture [[texture(0)]],
                                   constant BlurUniforms &u [[buffer(0)]]) {
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    const float weights[5] = {0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216};
    float4 result = sourceTexture.sample(smp, in.uv) * weights[0];
    for (int i = 1; i < 5; ++i) {
        float2 offset = u.direction * float(i);
        result += sourceTexture.sample(smp, in.uv + offset) * weights[i];
        result += sourceTexture.sample(smp, in.uv - offset) * weights[i];
    }
    return result;
}

// ------------------------------------------------------------
// Composite: scene + bloom * intensity
// ------------------------------------------------------------

struct CompositeUniforms {
    float intensity;
};

fragment float4 bloomCompositeFragment(FullscreenVertexOut in [[stage_in]],
                                        texture2d<float> sceneTexture [[texture(0)]],
                                        texture2d<float> bloomTexture [[texture(1)]],
                                        constant CompositeUniforms &u [[buffer(0)]]) {
    constexpr sampler smp(filter::linear, address::clamp_to_edge);
    float4 scene = sceneTexture.sample(smp, in.uv);
    float4 bloom = bloomTexture.sample(smp, in.uv);
    return float4(scene.rgb + bloom.rgb * u.intensity, scene.a);
}
