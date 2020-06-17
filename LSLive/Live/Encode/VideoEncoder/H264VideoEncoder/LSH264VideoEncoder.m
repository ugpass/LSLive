//
//  LSVideoEncoder.m
//  LSLive
//
//  Created by demo on 2020/6/4.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSH264VideoEncoder.h"

@interface LSH264VideoEncoder()
{
    VTCompressionSessionRef mVTCompressionSessionRef;
    
    unsigned long long frameID;
}
@end

@implementation LSH264VideoEncoder

- (instancetype)init {
    self = [super init];
    if (self) {
        [self initVideoEncoder];
    }
    return self;
}

#pragma mark - Public
- (void)startVideoEncoderSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    switch (self.encoderType) {
        case LSVideoEncoderTypeVTH264:
            [self startVideoEncoderVTH264SampleBuffer:sampleBuffer];
            break;
            
        default:
            break;
    }
}

- (void)stopVideoEncoder {
    VTCompressionSessionCompleteFrames(mVTCompressionSessionRef, kCMTimeInvalid);
    VTCompressionSessionInvalidate(mVTCompressionSessionRef);
    mVTCompressionSessionRef = NULL;
    if (fileHandele) {
        [fileHandele closeFile];
        fileHandele = NULL;
    }
}

#pragma mark - Private
- (void)initVideoEncoder {
    switch (self.encoderType) {
        case LSVideoEncoderTypeVTH264:
            [self initVideoToolBox];
            break;
            
        default:
            break;
    }
}

- (void)initVideoToolBox {
    int width = 720, height = 1280;
    frameID = 0;
    //创建session
    OSStatus status;
    status = VTCompressionSessionCreate(
                                        NULL,
                                        width,
                                        height,
                                        kCMVideoCodecType_H264,
                                        NULL,
                                        NULL,
                                        NULL,
                                        didCompressOutputCallback,
                                        (__bridge void *)self,
                                        &mVTCompressionSessionRef);
    if (status != noErr) {
        NSLog(@"initVideoToolBox:: VTCompressionSessionCreate error= %d", (int)status);
        return;
    }
    //设置session属性
    //是否实时编码
    status = VTSessionSetProperty(mVTCompressionSessionRef, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    if (status != noErr) {
        NSLog(@"initVideoToolBox:: kVTCompressionPropertyKey_RealTime error= %d", (int)status);
        return;
    }
    
    //设置ProfileLevel
    status = VTSessionSetProperty(mVTCompressionSessionRef, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    if (status != noErr) {
        NSLog(@"initVideoToolBox:: kVTCompressionPropertyKey_ProfileLevel error= %d", (int)status);
        return;
    }
     
    //设置码率，均值，单位是byte
    int bitRate = width * height * 3 * 4 * 8;
    CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
    status = VTSessionSetProperty(mVTCompressionSessionRef, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
    if (status != noErr) {
        NSLog(@"initVideoToolBox:: kVTCompressionPropertyKey_AverageBitRate error= %d", (int)status);
        return;
    }
    
    //设置码率，上限，单位是bps
    NSArray *limit = @[@(bitRate * 1.5/8), @(1)];
    status =  VTSessionSetProperty(mVTCompressionSessionRef, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    if (status != noErr) {
        NSLog(@"initVideoToolBox:: kVTCompressionPropertyKey_DataRateLimits error= %d", (int)status);
        return;
    }
    
    
    //配置关键帧间隔
    //webrtc frameInterval设置7200， frameDuration设置240
    status = VTSessionSetProperty(mVTCompressionSessionRef, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(25));
    if (status != noErr) {
        NSLog(@"initVideoToolBox:: kVTCompressionPropertyKey_MaxKeyFrameInterval error= %d", (int)status);
        return;
    }
    
    //是否产生B帧
    status = VTSessionSetProperty(mVTCompressionSessionRef, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    if (status != noErr) {
        NSLog(@"initVideoToolBox:: kVTCompressionPropertyKey_AllowFrameReordering error= %d", (int)status);
        return;
    }
    
    //设置期望帧率
    int fps = 25;
    CFNumberRef  fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
    status =  VTSessionSetProperty(mVTCompressionSessionRef, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
    if (status != noErr) {
        NSLog(@"initVideoToolBox:: kVTCompressionPropertyKey_ExpectedFrameRate error= %d", (int)status);
        return;
    }
    
    status = VTCompressionSessionPrepareToEncodeFrames(mVTCompressionSessionRef);
    if (status != noErr) {
        NSLog(@"initVideoToolBox:: VTCompressionSessionPrepareToEncodeFrames error= %d", (int)status);
        return;
    }
}

- (NSData *)startCode {
    const Byte bytes[] = "\x00\x00\x00\x01";
    size_t length = sizeof(bytes) - 1;
    NSData *headerData = [NSData dataWithBytes:bytes length:length];
    return headerData;
}

- (void)startVideoEncoderVTH264SampleBuffer:
(CMSampleBufferRef)sampleBuffer {
    dispatch_sync(self.encoderQueue, ^{
            //拿到每一帧未编码数据
            CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
            
       // pts,必须设置，否则会导致编码出来的数据非常大，原因未知 CMTime pts = CMTimeMake(_frameCount, 1000); 为什么会数据非常大？CMTimeMake第一个参数表示第几个关键帧，第二个参数代表每秒钟多少个关键帧。填1000，画质会模糊。填你自己想要的帧率。25，15等等
            //设置帧时间 如果不设置会导致时间轴过长，时间戳以ms为单位
            CMTime presentationTimeStamp = CMTimeMake(frameID++, 600);
            
            VTEncodeInfoFlags flags;
            
            OSStatus status = VTCompressionSessionEncodeFrame(
                                                              mVTCompressionSessionRef,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              kCMTimeInvalid,
                                                              NULL,
                                                              (__bridge void *)self,
                                                              &flags);
            if (status != noErr) {
                NSLog(@"H.264:VTCompressionSessionEncodeFrame faild with %d", (int)status);
                [self stopVideoEncoder];
                return;
            }
        });
}

/**
 获取编码后的sps pps
 */
- (void)gotSpsPps:(NSData *)sps pps:(NSData *)pps {
    NSData *headerData = [self startCode];
    if (self.writeToFile) {
        [fileHandele writeData:headerData];
        [fileHandele writeData:sps];
        [fileHandele writeData:headerData];
        [fileHandele writeData:pps];
    }
    
    if ([self.delegate respondsToSelector:@selector(videoEncodeDidOutputData:isKeyFrame:)]) {
        NSMutableData *spsData = [[NSMutableData alloc] init];
        [spsData appendData:headerData];
        [spsData appendData:sps];
         [self.delegate videoEncodeDidOutputData:spsData isKeyFrame:YES];
        
        NSMutableData *ppsData = [[NSMutableData alloc] init];
        [ppsData appendData:headerData];
        [ppsData appendData:pps];
        [self.delegate videoEncodeDidOutputData:ppsData isKeyFrame:YES];
    }
}

/**
 获取编码后的数据
 */
- (void)gotEncodedData:(NSData *)encodedData isKeyFrame:(BOOL)keyFrame {
    NSData *headerData = [self startCode];
    if (self.writeToFile) {
        [fileHandele writeData:headerData];
        [fileHandele writeData:encodedData];
    }
    
    if ([self.delegate respondsToSelector:@selector(videoEncodeDidOutputData:isKeyFrame:)]) {
        NSMutableData *encodedDataNew = [[NSMutableData alloc] init];
        [encodedDataNew appendData:headerData];
        [encodedDataNew appendData:encodedData];
        
        [self.delegate videoEncodeDidOutputData:encodedDataNew isKeyFrame:keyFrame];
    }
}
 

void didCompressOutputCallback(void * CM_NULLABLE outputCallbackRefCon,
                               void * CM_NULLABLE sourceFrameRefCon,
                               OSStatus status,
                               VTEncodeInfoFlags infoFlags,
                               CM_NULLABLE CMSampleBufferRef sampleBuffer) {
    if (noErr != status || nil == sampleBuffer) {
        NSLog(@"VideoEncoder didCompressOutputCallback error: %d", (int)status);
        return;
    }
    
    if (nil == outputCallbackRefCon) {
        NSLog(@"VideoEncoder didCompressOutputCallback error: outputCallbackRefCon is nil");
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
         NSLog(@"VideoEncoder didCompressOutputCallback error: CMSampleBufferDataIsReady is NO");
         return;
    }
    
    if (infoFlags & kVTEncodeInfo_FrameDropped) {
         NSLog(@"VideoEncoder didCompressOutputCallback H264 dropped frame.");
         return;
    }
    
    LSH264VideoEncoder *encoder = (__bridge LSH264VideoEncoder *)outputCallbackRefCon;
    bool isKeyFrame = NO;
    
    //判断是否是关键帧
    CFArrayRef array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, 0);
    if (CFArrayGetCount(array)) {
        CFBooleanRef notSync;
        CFDictionaryRef dic = CFArrayGetValueAtIndex(array, 0);
        BOOL keyExits = CFDictionaryGetValueIfPresent(dic, kCMSampleAttachmentKey_NotSync, (const void**)&notSync);
        isKeyFrame = !keyExits || !CFBooleanGetValue(notSync);
    }
    
    if (isKeyFrame) {
        CMFormatDescriptionRef mFormatDescriptionRef = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        //关键帧 需要加上 SPS PPS信息
        //获取SPS信息
        size_t spsSize,spsCount;
        const uint8_t *spsData;
        OSStatus spsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(mFormatDescriptionRef, 0, &spsData, &spsSize, &spsCount, 0);
        
        //获取pps
        size_t ppsSize,ppsCount;
        const uint8_t *ppsData;
        OSStatus ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(mFormatDescriptionRef, 1, &ppsData, &ppsSize, &ppsCount, 0);
        
        if (spsStatus == noErr && ppsStatus == noErr) {
            NSData *sps = [NSData dataWithBytes:spsData length:spsSize];
            NSData *pps = [NSData dataWithBytes:ppsData length:ppsSize];
            
            if (encoder) {
                [encoder gotSpsPps:sps pps:pps];
            }
        }else {
            NSLog(@"LSVideoEncoer Callback:: get sps or pps error: spsStatus=%d ppsStatus=%d", (int)spsStatus, (int)ppsStatus);
            return;
        }
    }
    
    //获取编码后的buffer
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    
    size_t length, totalLength;
    char *dataPointer;
    OSStatus blockBufferStatus = CMBlockBufferGetDataPointer(blockBuffer, 0, &length, &totalLength, &dataPointer);
    
    if (blockBufferStatus != noErr) {
        NSLog(@"LSVideoEncoer Callback:: get blockBuffer dataPointer error: %d", (int)blockBufferStatus);
        return;
    }
    size_t bufferOffset = 0;
    
    //返回的nalu数据前4个字节不是001的startCode，而是大端模式的帧长度length
    static const int avcHeanderLength = 4;
    
    //循环获取nalu数据
    while (bufferOffset < totalLength - avcHeanderLength) {
        uint32_t nalUnitLength = 0;
        //读取 一单元长度的 nalu
        memcpy(&nalUnitLength, dataPointer + bufferOffset, avcHeanderLength);
        
        //大端模式 转 小端模式
        nalUnitLength = CFSwapInt32BigToHost(nalUnitLength);
        
        //获取nalu数据
        NSData *naluData = [NSData dataWithBytes:(dataPointer + bufferOffset + avcHeanderLength) length:nalUnitLength];
        
        if (encoder) {
            [encoder gotEncodedData:naluData isKeyFrame:isKeyFrame];
        }
        
        bufferOffset += avcHeanderLength + nalUnitLength;
    }
}

- (void)dealloc {
    [self stopVideoEncoder];
    NSLog(@"%s", __func__);
}

@end
