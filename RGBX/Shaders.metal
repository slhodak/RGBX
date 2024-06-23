#include <metal_stdlib>
using namespace metal;

struct VertexUniforms {
    float2 textureScale;
    int shouldResize;
};

struct VertexIn {
    float3 position     [[attribute(0)]];
    float2 texCoords    [[attribute(2)]];
};

struct VertexOut {
    float4 position     [[position]];
    float2 texCoords;
};

struct FragmentUniforms {
    int fragmentP1;
    int fragmentP2;
    int fragmentP3;
    uchar fragmentPr;
    uchar fragmentPg;
    uchar fragmentPb;
    bool usingOriginalMaterial;
};

vertex VertexOut vertex_main(VertexIn v_in [[stage_in]],
                             constant VertexUniforms &vertexUniforms [[buffer(1)]]) {
    VertexOut v_out;
    v_out.position = float4(v_in.position, 1);
    if (vertexUniforms.shouldResize == 1) {
        v_out.texCoords = v_in.texCoords * vertexUniforms.textureScale;
    } else {
        v_out.texCoords = v_in.texCoords;
    }
    return v_out;
};

fragment float4 fragment_main(VertexOut frag_in [[stage_in]],
                              texture2d<float, access::sample> texture [[texture(0)]],
                              constant FragmentUniforms &uniforms [[buffer(0)]],
                              sampler baseColorSampler [[sampler(0)]]) {
    float3 baseColor = texture.sample(baseColorSampler, frag_in.texCoords).rgb;
    
    if (uniforms.usingOriginalMaterial == true) {
        return float4(baseColor, 1);
    }
    
    int n = (frag_in.position.y * texture.get_width()) + frag_in.position.x;
    
    uchar r = baseColor.x * UCHAR_MAX;
    uchar g = baseColor.y * UCHAR_MAX;
    uchar b = baseColor.z * UCHAR_MAX;
    
    if (n < uniforms.fragmentP1) {
        r = (r + uniforms.fragmentPr) % UCHAR_MAX;
    } else {
        r = r - uniforms.fragmentPr;
    }
    
    if (n < uniforms.fragmentP2) {
        g = (g + uniforms.fragmentPg) % UCHAR_MAX;
    } else {
        g = g - uniforms.fragmentPg;
    }
    
    if (n < uniforms.fragmentP3) {
        b = (b + uniforms.fragmentPb) % UCHAR_MAX;
    } else {
        b = b - uniforms.fragmentPb;
    }

    return float4(float(r)/float(UCHAR_MAX),
                  float(g)/float(UCHAR_MAX),
                  float(b)/float(UCHAR_MAX),
                  1);
};
