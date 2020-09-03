//
//  LSMetalView.m
//  LSLive
//
//  Created by demo on 2020/9/3.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSMetalView.h"
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

@interface LSMetalView()

//命令队列
@property (nonatomic, strong)id<MTLCommandQueue> commandQueue;

//纹理缓冲区
@property (nonatomic, assign)CVMetalTextureCacheRef textureCache;

//纹理textureY
@property (nonatomic, strong)id<MTLTexture> textureY;

//纹理textureCrCb
@property (nonatomic, strong)id<MTLTexture> textureCrCb;

//渲染管道
@property (nonatomic, strong)id<MTLRenderPipelineState> pipeline;
@end

@implementation LSMetalView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupMetal];
    }
    return self;
}

#pragma - 开始渲染
- (void)startRenderWithSamplerBuffer:(CVPixelBufferRef)pixelBuffer {
    
    id<MTLTexture> textureY = NULL;
    id<MTLTexture> textureCrCb = NULL;
    
    //textureY
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        
        MTLPixelFormat pixelFormat = MTLPixelFormatR8Unorm;
        CVMetalTextureRef tempTexture = NULL;
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, pixelBuffer, NULL, pixelFormat, width, height, 0, &tempTexture);
        if (status == kCVReturnSuccess) {
            textureY = CVMetalTextureGetTexture(tempTexture);
            CFRelease(tempTexture);
        }
    }
    
    //TextureCrCb
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        
        MTLPixelFormat pixelFormat = MTLPixelFormatRG8Unorm;
        CVMetalTextureRef tempTexture = NULL;
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, pixelBuffer, NULL, pixelFormat, width, height, 1, &tempTexture);
        if (status == kCVReturnSuccess) {
            textureCrCb = CVMetalTextureGetTexture(tempTexture);
            CFRelease(tempTexture);
        }
    }
    
    if (textureY && textureCrCb) {
        _textureY = textureY;
        _textureCrCb = textureCrCb;
    }
    
    
    
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
        
        //将MTKView作为目标 渲染纹理
        id<MTLTexture> drawableTexture = view.currentDrawable.texture;
        
        MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
        
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
     
       
        
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
- (void)setupMetal {
    //给MTKView设置 设备
    self.device = MTLCreateSystemDefaultDevice();
    //设置代理
    self.delegate = self;
    //设置命令队列
    self.commandQueue = [self.device newCommandQueue];
    //设置纹理可读写，默认是只读
    self.framebufferOnly  = NO;
    //创建纹理缓冲区
    CVMetalTextureCacheCreate(NULL, NULL, self.device, NULL, &_textureCache);
}

@end
