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

//YUV转RGB矩阵
typedef struct {
    matrix_float3x3 matrix;
    vector_float3 offset;
} ColorConversion;

#endif /* LSShaderType_h */
