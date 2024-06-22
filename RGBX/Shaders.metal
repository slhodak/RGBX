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
    int drawableHeight;
    int drawableWidth;
};

vertex VertexOut vertex_main(VertexIn v_in [[stage_in]],
                             constant VertexUniforms &vertexUniforms [[buffer(1)]]) {
    VertexOut v_out;
    v_out.position = float4(v_in.position, 1);
    v_out.texCoords = v_in.texCoords * vertexUniforms.textureScale;
    return v_out;
};

fragment float4 fragment_main(VertexOut frag_in [[stage_in]],
                              texture2d<float> renderTarget [[texture(0)]]) {
    int totalFragments = renderTarget.get_width() * renderTarget.get_height();
    int n = (frag_in.position.y * renderTarget.get_width()) + frag_in.position.x;
    
    uchar r = 0b00000000;
    uchar g = 0b00000000;
    uchar b = 0b00000000;
    
    if (n % 7 == 0) {
        r = UCHAR_MAX;
        g = UCHAR_MAX;
        b = UCHAR_MAX;
    } else if (n % 6 == 0) {
        r = UCHAR_MAX;
        g = 0b0;
        b = 0b0;
    } else if (n % 4 == 0) {
        r = 0b0;
        g = UCHAR_MAX;
        b = 0b0;
    } else if (n % 3 == 0) {
        r = 0b0;
        g = 0b0;
        b = UCHAR_MAX;
    }
    
    return float4(float(r)/UCHAR_MAX, float(g)/UCHAR_MAX, float(b)/UCHAR_MAX, 1);
};
