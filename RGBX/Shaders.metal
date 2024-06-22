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
    float2 viewportSize;
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
    //    for i in 0..<pixelCount {
    //        colorData.append(color)
    //        if i % Int(textureP3) == 0 {
    //            color = color << UInt32(textureP1)
    //        } else if i % Int(textureP4) == 0 {
    //            color = color >> UInt32(textureP2)
    //        }
    //        color = (color + 1) % colorMask
    //        color = color | opaque
    //    }
    
    /// Get the pixel value based on xy and total size
    // n = (row * rows) + column
    // frag_in.position is viewport coordinate system
    
    uint totalPixels = renderTarget.get_width() * renderTarget.get_height();
    
    uint n = (frag_in.position.y * renderTarget.get_width()) + frag_in.position.x;
    uint normalizedN = n / totalPixels;
    uint color = normalizedN % 0xFF;
    
    return float4(frag_in.position.y / renderTarget.get_width(),
                  color,
                  color,
                  1);
};
