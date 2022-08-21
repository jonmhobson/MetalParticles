#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

struct RasterizerData {
    float4 position [[position]];
    float pointSize [[point_size]];
    float2 uv;
};

struct Particle {
    float2 position;
    float2 initialPos;
    float2 velocity;
    float2 acceleration;
    float life;
};

float3 hash( float3 p )
{
    p = float3(dot(p,float3(127.1,311.7, 74.7)),
               dot(p,float3(269.5,183.3,246.1)),
               dot(p,float3(113.5,271.9,124.6)));

    return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

// Noised and hash functions by Inigo Quilez: https://www.shadertoy.com/view/4dffRH
float noised( float3 x ) {
    // grid
    float3 i = floor(x);
    float3 w = fract(x);

    // quintic interpolant
    float3 u = w*w*w*(w*(w*6.0-15.0)+10.0);

    // gradients
    float3 ga = hash( i+float3(0.0,0.0,0.0) );
    float3 gb = hash( i+float3(1.0,0.0,0.0) );
    float3 gc = hash( i+float3(0.0,1.0,0.0) );
    float3 gd = hash( i+float3(1.0,1.0,0.0) );
    float3 ge = hash( i+float3(0.0,0.0,1.0) );
    float3 gf = hash( i+float3(1.0,0.0,1.0) );
    float3 gg = hash( i+float3(0.0,1.0,1.0) );
    float3 gh = hash( i+float3(1.0,1.0,1.0) );

    // projections
    float va = dot( ga, w-float3(0.0,0.0,0.0) );
    float vb = dot( gb, w-float3(1.0,0.0,0.0) );
    float vc = dot( gc, w-float3(0.0,1.0,0.0) );
    float vd = dot( gd, w-float3(1.0,1.0,0.0) );
    float ve = dot( ge, w-float3(0.0,0.0,1.0) );
    float vf = dot( gf, w-float3(1.0,0.0,1.0) );
    float vg = dot( gg, w-float3(0.0,1.0,1.0) );
    float vh = dot( gh, w-float3(1.0,1.0,1.0) );

    // interpolations
    return va + u.x*(vb-va) + u.y*(vc-va) + u.z*(ve-va) + u.x*u.y*(va-vb-vc+vd) + u.y*u.z*(va-vc-ve+vg) + u.z*u.x*(va-vb-ve+vf) + (-va+vb+vc-vd+ve-vf-vg+vh)*u.x*u.y*u.z;
}

kernel void particleMove(device Particle* particles [[buffer(0)]],
                         device Vertex *vertices [[buffer(1)]],
                         uint id [[thread_position_in_grid]]) {

    particles[id].life += 0.05;

    float life = particles[id].life;

    float scale = 0.002;
    float noise = noised(float3(scale * particles[id].position.x, scale * particles[id].position.y, life * 0.04));
    float angle = noise * 4.0 * 3.141592653589793;

    float c0 = cos(angle);
    float s0 = sin(angle);

    float vx = 0.0;
    float vy = 1.0;

    float homeAmt = 1.0 - saturate(1.0 + 0.3 * sin(0.05 * life));

    float2 noiseV = float2(c0 * vx - s0 * vy, s0 * vx + c0 * vy) * 0.07;
    float2 homeV = (particles[id].initialPos - particles[id].position) * homeAmt * homeAmt * homeAmt * 3.3;

    particles[id].acceleration = mix(noiseV, homeV, saturate(homeAmt * homeAmt + 0.1));

    particles[id].velocity += particles[id].acceleration;
    particles[id].velocity *= mix(0.995, 0.8, homeAmt * homeAmt);
    particles[id].position += particles[id].velocity;

    particles[id].acceleration = float2(0, 0);

    vertices[id].position = particles[id].position;
    vertices[id].uv = particles[id].initialPos;
    vertices[id].uv.y = -vertices[id].uv.y;
}

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                   constant Vertex *vertices [[buffer(0)]],
                                   constant vector_uint2 *viewportSizePointer [[buffer(1)]]) {
    RasterizerData out;

    float2 pixelSpacePosition = vertices[vertexID].position.xy;
    vector_float2 viewportSize = vector_float2(*viewportSizePointer);

    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = pixelSpacePosition / (viewportSize / 2.0);

    out.pointSize = 1.0;

    out.uv = (vertices[vertexID].uv / (viewportSize / 2.0)) * 0.5 + 0.5;

    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture2d<half> colorTexture [[ texture(0)]]) {

    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear,
                                      s_address::clamp_to_edge,
                                      t_address::clamp_to_edge);

    const half4 colorSample = colorTexture.sample(textureSampler, in.uv);
    return pow(float4(colorSample), 1.0);
}
