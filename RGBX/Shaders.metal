#include <metal_stdlib>
using namespace metal;

struct VertexUniforms {
    float2 textureScale;
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
    uchar fragmentP1;
    uchar fragmentP2;
    uchar fragmentPr;
    uchar fragmentPg;
    uchar fragmentPb;
};

vertex VertexOut vertex_main(VertexIn v_in [[stage_in]],
                             constant VertexUniforms &vertexUniforms [[buffer(1)]]) {
    VertexOut v_out;
    v_out.position = float4(v_in.position, 1);
    v_out.texCoords = v_in.texCoords * vertexUniforms.textureScale;
    return v_out;
};

fragment float4 fragment_main(VertexOut frag_in [[stage_in]],
                              texture2d<float> renderTarget [[texture(0)]],
                              constant FragmentUniforms &uniforms [[buffer(0)]]) {
    //int totalFragments = renderTarget.get_width() * renderTarget.get_height();
    int n = (frag_in.position.y * renderTarget.get_width()) + frag_in.position.x;
    
    uchar r = uniforms.fragmentPr * n;
    uchar g = uniforms.fragmentPg * n;
    uchar b = uniforms.fragmentPb * n;
    
    if (n % uniforms.fragmentP1 == 0) {
        r = r >> uniforms.fragmentPr;
        g = g >> uniforms.fragmentPg;
        b = b >> uniforms.fragmentPb;
    } else if (n % uniforms.fragmentP2 == 0) {
        r = r << uniforms.fragmentPr;
        g = g << uniforms.fragmentPg;
        b = b << uniforms.fragmentPb;
    }
    
    return float4(float(r)/UCHAR_MAX, float(g)/UCHAR_MAX, float(b)/UCHAR_MAX, 1);
};
