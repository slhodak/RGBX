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

vertex VertexOut vertex_main(VertexIn v_in [[stage_in]],
                             constant VertexUniforms &vertexUniforms [[buffer(1)]]) {
    VertexOut v_out;
    v_out.position = float4(v_in.position, 1);
    v_out.texCoords = v_in.texCoords * vertexUniforms.textureScale;
    return v_out;
};

fragment float4 fragment_main(VertexOut frag_in [[stage_in]],
                              texture2d<float> renderTarget [[texture(0)]]) {
//    UInt32 opaque = 0b11111111_00000000_00000000_00000000
//    var color: UInt32       = 0b11111111_00000000_00000000_00000000
//    let colorMask: UInt32   = 0b00000000_11111111_11111111_11111111
//    var colorData: [UInt32] = []
//    
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
    
    uint2 textureSize = uint2(renderTarget.get_width(), renderTarget.get_height());
    float2 normalizedPos = frag_in.position.xy / float2(textureSize);
    
    return float4(normalizedPos.x, normalizedPos.y, 0, 1);
};
