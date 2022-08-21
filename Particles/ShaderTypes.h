//
//  ShaderTypes.h
//  Particles
//
//  Created by Jonathan Hobson on 18/08/2022.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs
// match Metal API buffer set calls.
typedef enum AAPLVertexInputIndex
{
    AAPLVertexInputIndexVertices     = 0,
    AAPLVertexInputIndexViewportSize = 1,
} AAPLVertexInputIndex;

typedef struct
{
    vector_float2 position;
    vector_float4 color;
    vector_float2 uv;
} Vertex;

#endif /* ShaderTypes_h */
