//
//  LSOpenGLESView.m
//  LSLive
//
//  Created by demo on 2020/9/7.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSOpenGLESView.h"
#import "GLESUtils.h"

@interface LSOpenGLESView()
{
    int bufferWidth;
    int bufferHeight;
}

@property (nonatomic, strong) CAEAGLLayer *eaglLayer;
@property (nonatomic, strong) EAGLContext *context;

@property (nonatomic, assign) GLuint renderBuffer;//渲染缓冲区ID
@property (nonatomic, assign) GLuint frameBuffer;//帧缓冲区ID

@property (nonatomic, assign) GLuint textureYID;//Y分量缓冲区ID
@property (nonatomic, assign) GLuint textureUVID;//Y分量缓冲区ID

@property (nonatomic, assign) GLuint program;//program ID

@property (nonatomic, assign) CVOpenGLESTextureCacheRef texutreCache;

//Attribuite传入顶点着色器
@property (nonatomic, assign) GLuint vertexPositionAttribuite;//顶点坐标通道
@property (nonatomic, assign) GLuint textureCoordAttribuite;//纹理坐标通道

//uniform 传入片元着色器
@property (nonatomic, assign) GLuint textureSamplerY;//Y分量采样器
@property (nonatomic, assign) GLuint textureSamplerUV;//UV分量采样器
@property (nonatomic, assign) GLuint colorConversionMatrix;//YUV转RGB矩阵


@end

@implementation LSOpenGLESView
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLayer];
        [self setupContext];
        [self clearRenderAndFrameBuffer];
        [self setupRenderBuffer];
        [self setupFrameBuffer];
        [self setupTextureCache];
        [self setupProgram];
        [self setupVertexFragmentID];
    }
    return self;
}

- (void)layoutSubviews {
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
}

- (void)startRenderWithSamplerBuffer:(CVPixelBufferRef)sampleBuffer {
    bufferWidth = (int) CVPixelBufferGetWidth(sampleBuffer);
    bufferHeight = (int) CVPixelBufferGetHeight(sampleBuffer);
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"%d-%d", bufferWidth, bufferHeight);
    });
    
    [EAGLContext setCurrentContext:self.context];
    
    CVOpenGLESTextureRef textureY = NULL;
    CVOpenGLESTextureRef textureUV = NULL;
    
    //判断YUV格式
    if (CVPixelBufferGetPlaneCount(sampleBuffer) > 0) {
        //加锁
        CVPixelBufferLockBaseAddress(sampleBuffer, 0);
        
        //Y分量
        glActiveTexture(GL_TEXTURE4);
        CVReturn err;
        
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.texutreCache, sampleBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &textureY);
        if (err) {
            NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage Y error = %d", err);
        }
        self.textureYID = CVOpenGLESTextureGetName(textureY);
        glBindTexture(GL_TEXTURE_2D, self.textureYID);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        //UV分量
        glActiveTexture(GL_TEXTURE5);
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.texutreCache, sampleBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &textureUV);
        if (err) {
            NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage UV error = %d", err);
        }
        
        self.textureUVID = CVOpenGLESTextureGetName(textureUV);
        glBindTexture(GL_TEXTURE_2D, self.textureUVID);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        //convert YUV to RGB
        [self convertYUVToRGBOutput];
        
        CVPixelBufferUnlockBaseAddress(sampleBuffer, 0);
        CFRelease(textureY);
        CFRelease(textureUV);
        CVPixelBufferRelease(sampleBuffer);//记得释放 不然内存会一直暴涨
    }
}

- (void)dealloc {
    NSLog(@"%s", __func__);
    //需要清空缓冲区 不然会有内存泄漏
    CVOpenGLESTextureCacheFlush(_texutreCache, 0);
    
    if (_frameBuffer) {
        glDeleteFramebuffers(1, &_frameBuffer);
        _frameBuffer = 0;
    }
    
    if (_renderBuffer) {
        glDeleteRenderbuffers(1, &_renderBuffer);
        _renderBuffer = 0;
    }
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    _context = nil;
}

#pragma mark - private
///1.设置layer
- (void)setupLayer {
    self.eaglLayer = (CAEAGLLayer *)self.layer;
    [self setContentScaleFactor:[UIScreen mainScreen].scale];
    self.eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:@false, kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    NSLog(@"%s__%@", __func__, self.eaglLayer);
}

///2.设置上下文
- (void)setupContext {
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!self.context) {
        NSLog(@"create EAGLContext failed");
        return;
    }
    
    BOOL ret = [EAGLContext setCurrentContext:self.context];
    if (!ret) {
        NSLog(@"set current context failed");
        return;
    }
    NSLog(@"%s__%@", __func__, self.context);
}

///3.清空缓冲区
- (void)clearRenderAndFrameBuffer {
    glDeleteRenderbuffers(1, &_renderBuffer);
    self.renderBuffer = 0;
    
    glDeleteFramebuffers(1, &_frameBuffer);
    self.frameBuffer = 0;
}

///4.设置renderBuffer
- (void)setupRenderBuffer {
    GLuint renderBuffer;
    glGenRenderbuffers(1, &renderBuffer);
    self.renderBuffer = renderBuffer;
    
    glBindRenderbuffer(GL_RENDERBUFFER, self.renderBuffer);
    [self.context renderbufferStorage:self.renderBuffer fromDrawable:self.eaglLayer];
}

///5.设置frameBuffer
- (void)setupFrameBuffer {
    GLuint frameBuffer;
    glGenFramebuffers(1, &frameBuffer);
    self.frameBuffer = frameBuffer;
    
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, self.renderBuffer);
}

///6.设置 纹理缓冲区
- (void)setupTextureCache {
    CVReturn res = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.context, NULL, &_texutreCache);
    if (res != kCVReturnSuccess) {
        NSLog(@"create texture cache failed");
        return;
    }
}

//配置顶点着色器和纹理着色器中属性
- (void)setupVertexFragmentID {
    self.vertexPositionAttribuite = glGetAttribLocation(self.program, "position");
    self.textureCoordAttribuite = glGetAttribLocation(self.program, "inputTextureCoordinate");
    
    self.textureSamplerY = glGetUniformLocation(self.program, "textureSamplerY");
    self.textureSamplerUV = glGetUniformLocation(self.program, "texutreSamplerUV");
    self.colorConversionMatrix = glGetUniformLocation(self.program, "colorConversionMatrix");
    
    //attribuite通道默认关闭 需要手动打开
    glEnableVertexAttribArray(self.vertexPositionAttribuite);
    glEnableVertexAttribArray(self.textureCoordAttribuite);
    
}

///创建program
- (void)setupProgram {
    NSString *vertextPath = [[NSBundle mainBundle] pathForResource:@"shaderv" ofType:@"vsh"];
    NSString *fragmentPath = [[NSBundle mainBundle] pathForResource:@"shaderf" ofType:@"fsh"];
    GLuint program = [GLESUtils loadProgram:vertextPath withFragmentShaderFilepath:fragmentPath];
    self.program = program;
}

///convert YUV to RGB
- (void)convertYUVToRGBOutput {
    
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glViewport(0, 0, self.frame.size.width * 2, self.frame.size.height * 2);
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glUseProgram(self.program);
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    //YUV420 转RGB 矩阵
    static const GLfloat preferredConversion[] = {
        1.164,  1.164, 1.164,
        0.0, -0.392, 2.017,
        1.596, -0.813,   0.0,
    };
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, self.textureYID);
    glUniform1i(self.vertexPositionAttribuite, 4);

    glActiveTexture(GL_TEXTURE5);
    glBindTexture(GL_TEXTURE_2D, self.textureUVID);
    glUniform1i(self.textureCoordAttribuite, 5);

    glUniformMatrix3fv(self.colorConversionMatrix, 1, GL_FALSE, preferredConversion);

    //旋转矩阵 垂直翻转
    static const GLfloat noRotationTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f,  0.0f,
        1.0f,  0.0f,
    };

    glVertexAttribPointer(self.vertexPositionAttribuite, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(self.textureCoordAttribuite, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

@end
