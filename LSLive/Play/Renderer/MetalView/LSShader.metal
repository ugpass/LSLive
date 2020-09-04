//
//  LSShader.metal
//  LSLive
//
//  Created by demo on 2020/9/3.
//  Copyright © 2020 ls. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#import "LSShaderType.h"

typedef struct {
    float4 clipSpacePosition [[position]];
    float2 textureCoordinate;
} RasterizerData;


vertex RasterizerData vertexPassthrough(
                                        uint vertexID [[ vertex_id ]],
                                        constant Vertex* vertexArray [[ buffer(0) ]]
) {
    //顶点坐标原样输出 纹理坐标透传到片元着色器
    RasterizerData out;
    //顶点坐标
    out.clipSpacePosition = vertexArray[vertexID].position;
    //纹理坐标
    out.textureCoordinate = vertexArray[vertexID].texcoord;
    
    return out;
}

fragment half4 fragmentColorConversion(
    RasterizerData in [[ stage_in ]],
    texture2d<float, access::sample> textureY [[ texture(0) ]],
    texture2d<float, access::sample> textureCbCr [[ texture(1) ]],
    constant ColorConversion &colorConversion [[ buffer(0) ]]
) {
    //纹理采样器
    constexpr sampler textureSampler(filter::linear, filter::linear);
    //读取YUV的数据
    float3 ycbcr = float3(textureY.sample(textureSampler, in.textureCoordinate).r, textureCbCr.sample(textureSampler, in.textureCoordinate).rg);
    
    //将YVU转成RGB
    float3 rgb = colorConversion.matrix * (ycbcr + colorConversion.offset);
    
    return half4(half3(rgb), 1.0);
}
