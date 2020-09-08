//
//  LSMetalView.m
//  LSLive
//
//  Created by demo on 2020/9/3.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSMetalView.h"
#import "LSShaderType.h"


static const Vertex cubeVertexData[] =
{   // 顶点坐标，分别是x、y、z、w；    纹理坐标，x、y；
    { {  1.0, -1.0, 0.0, 1.0 },  { 1.f, 1.f } },
    { { -1.0, -1.0, 0.0, 1.0 },  { 0.f, 1.f } },
    { { -1.0,  1.0, 0.0, 1.0 },  { 0.f, 0.f } },
    
    { {  1.0, -1.0, 0.0, 1.0 },  { 1.f, 1.f } },
    { { -1.0,  1.0, 0.0, 1.0 },  { 0.f, 0.f } },
    { {  1.0,  1.0, 0.0, 1.0 },  { 1.f, 0.f } },
};
//float cubeVertexData[16] =
//{
//    -1.0, -1.0,  0.0, 1.0,
//     1.0, -1.0,  1.0, 1.0,
//    -1.0,  1.0,  0.0, 0.0,
//     1.0,  1.0,  1.0, 0.0,
//};

@interface LSMetalView()

//命令队列
@property (nonatomic, strong)id<MTLCommandQueue> commandQueue;

//纹理缓冲区
@property (nonatomic, assign)CVMetalTextureCacheRef textureCache;

//纹理textureY
@property (nonatomic, strong)id<MTLTexture> textureY;

//纹理textureCrCb
@property (nonatomic, strong)id<MTLTexture> textureCrCb;

//顶点缓冲区
@property (nonatomic, strong)id<MTLBuffer> vertexBuffer;

@property (nonatomic, strong)id<MTLBuffer> colorConversionBuffer;

@property (nonatomic, strong)id<MTLLibrary> defaultLibrary;

//viewportSize 视口大小
@property (nonatomic, assign) vector_uint2 viewportSize;

//渲染管道
@property (nonatomic, strong)id<MTLRenderPipelineState> pipelineState;

//顶点个数
@property (nonatomic, assign) NSUInteger numVertices;
@end

@implementation LSMetalView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupMetal];
        [self setupPipiline];
        [self setupVertex];
        [self setupMatrix];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"%s", __func__);
    //需要清空缓冲区 不然会有内存泄漏
    CVMetalTextureCacheFlush(_textureCache, 0);
    if (_textureY) {
        _textureY = NULL;
    }
    if (_textureCrCb) {
        _textureCrCb = NULL;
    }
}

#pragma - 开始渲染
- (void)startRenderWithSamplerBuffer:(CVPixelBufferRef)pixelBuffer {
    
    id<MTLTexture> textureY = NULL;
    id<MTLTexture> textureCrCb = NULL;
    
    //textureY
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, LSPixelFormatY);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, LSPixelFormatY);
        
        MTLPixelFormat pixelFormat = MTLPixelFormatR8Unorm;
        
        CVMetalTextureRef tempTexture = NULL;
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, pixelBuffer, NULL, pixelFormat, width, height, LSPixelFormatY, &tempTexture);
        if (status == kCVReturnSuccess) {
            textureY = CVMetalTextureGetTexture(tempTexture);
            CFRelease(tempTexture);
        }
    }
    
    //TextureCrCb
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, LSPixelFormatUV);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, LSPixelFormatUV);
        
        MTLPixelFormat pixelFormat = MTLPixelFormatRG8Unorm;
        CVMetalTextureRef tempTexture = NULL;
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, pixelBuffer, NULL, pixelFormat, width, height, LSPixelFormatUV, &tempTexture);
        if (status == kCVReturnSuccess) {
            textureCrCb = CVMetalTextureGetTexture(tempTexture);
            CFRelease(tempTexture);
        }
    }
    
    if (textureY && textureCrCb) {
        _textureY = textureY;
        _textureCrCb = textureCrCb;
    }
    
    CVPixelBufferRelease(pixelBuffer);
    
}

#pragma mark - MTKViewDelegate
/*!
 @method mtkView:drawableSizeWillChange:
 @abstract Called whenever the drawableSize of the view will change
 @discussion Delegate can recompute view and projection matricies or regenerate any buffers to be compatible with the new view size or resolution
 @param view MTKView which called this method
 @param size New drawable size in pixels
 */
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.viewportSize = (vector_uint2){size.width, size.height};
}

/*!
 @method drawInMTKView:
 @abstract Called on the delegate when it is asked to render into the view
 @discussion Called on the delegate when it is asked to render into the view
 */
- (void)drawInMTKView:(nonnull MTKView *)view {
    //判断是否获取到了纹理
    if (self.textureY && self.textureCrCb) {
        //为当前渲染的每个纹理 创建一个新的命令缓冲区
        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
        commandBuffer.label = @"LS_Metal_View_CommandBuffer";
        
        MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0f);
        
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        
        //设置视口大小
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, self.viewportSize.x, self.viewportSize.y, -1.0, 1.0 }];
     
        [renderEncoder setRenderPipelineState:self.pipelineState];
        
        [renderEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:self.textureY atIndex:LSPixelFormatY];
        [renderEncoder setFragmentTexture:self.textureCrCb atIndex:LSPixelFormatUV];
        
        [renderEncoder setFragmentBuffer:self.colorConversionBuffer offset:0 atIndex:0];
        
        
        
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.numVertices];
        
        
        [renderEncoder endEncoding];
        
        //6.展示显示的内容
        [commandBuffer presentDrawable:view.currentDrawable];
        
        //7.提交命令
        [commandBuffer commit];
        
        //8.清空当前纹理,准备下一次的纹理数据读取.
        self.textureY = NULL;
        self.textureCrCb = NULL;
    }
}


#pragma mark - private
//1.设置metal
- (void)setupMetal {
    //给MTKView设置 设备
    self.device = MTLCreateSystemDefaultDevice();
    
    //设置代理
    self.delegate = self;
    
    //设置纹理可读写，默认是只读
    self.framebufferOnly  = NO;
    
    //获取视口size
    self.viewportSize = (vector_uint2){self.drawableSize.width, self.drawableSize.height};
    //创建纹理缓冲区
    CVMetalTextureCacheCreate(NULL, NULL, self.device, NULL, &_textureCache);
    
}

//2.设置管道
- (void)setupPipiline {
    //获取.metal文件
    //newDefaultLibrary 默认1个metal文件时可以使用
    self.defaultLibrary = [self.device newDefaultLibrary];
    //片元函数
    id <MTLFunction> fragmentProgram = [self.defaultLibrary newFunctionWithName:@"fragmentColorConversion"];
     //顶点函数
    id <MTLFunction> vertexProgram = [self.defaultLibrary newFunctionWithName:@"vertexPassthrough"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.label = @"LS_PIPELINE";
    [pipelineDescriptor setSampleCount:1];
    [pipelineDescriptor setVertexFunction:vertexProgram];
    [pipelineDescriptor setFragmentFunction:fragmentProgram];
    pipelineDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:nil];
    if (!self.pipelineState) {
        NSLog(@"failed create pipeline state");
    }
    
    //设置命令队列
    self.commandQueue = [self.device newCommandQueue];
}

//3.设置顶点数据
- (void)setupVertex {
    //顶点缓冲区
    self.vertexBuffer = [self.device newBufferWithBytes:cubeVertexData length:sizeof(cubeVertexData) options:MTLResourceStorageModeShared];
    self.vertexBuffer.label = @"Vertices";
    //3.计算顶点个数
    self.numVertices = sizeof(cubeVertexData) / sizeof(Vertex);
}

//4.设置转换矩阵
- (void)setupMatrix {
    ColorConversion colorConversion = {
        .matrix = {
            .columns[0] = { 1.164,  1.164, 1.164, },
            .columns[1] = { 0.000, -0.392, 2.017, },
            .columns[2] = { 1.596, -0.813, 0.000, },
        },
        .offset = { -(16.0/255.0), -0.5, -0.5 },
    };
    
    self.colorConversionBuffer = [self.device newBufferWithBytes:&colorConversion length:sizeof(ColorConversion) options:MTLResourceStorageModeShared];
}


@end
