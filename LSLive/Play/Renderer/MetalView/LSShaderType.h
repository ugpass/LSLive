//
//  LSShaderType.h
//  LSLive
//
//  Created by demo on 2020/9/3.
//  Copyright © 2020 ls. All rights reserved.
//

#ifndef LSShaderType_h
#define LSShaderType_h

#include <simd/simd.h>

typedef enum LSPixelFormatYUV {
    LSPixelFormatY = 0,
    LSPixelFormatUV = 1
} LSPixelFormatYUV;
 

//YUV转RGB矩阵
typedef struct {
    matrix_float3x3 matrix;
    vector_float3 offset;
} ColorConversion;

//顶点信息
typedef struct {
    vector_float4 position;//顶点坐标
    vector_float2 texcoord;//纹理坐标 透出到片元着色器
} Vertex;

#endif /* LSShaderType_h */
