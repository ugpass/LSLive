//
//  LSVideoDecoder.m
//  LSLive
//
//  Created by demo on 2020/6/7.
//  Copyright © 2020 ls. All rights reserved.
//
/**
 在读取到I P B帧视频帧时才去初始化解码器，
 因为初始化解码器需要从视频帧中读取宽高以及解码相关参数
 */

#import "LSVideoDecoder.h"
NSString * const naluTypesStrings[] =
{
 @"0: Unspecified (non-VCL)",
 @"1: Coded slice of a non-IDR picture (VCL)", // P frame
 @"2: Coded slice data partition A (VCL)",
 @"3: Coded slice data partition B (VCL)",
 @"4: Coded slice data partition C (VCL)",
 @"5: Coded slice of an IDR picture (VCL)", // I frame
 @"6: Supplemental enhancement information (SEI) (non-VCL)",
 @"7: Sequence parameter set (non-VCL)", // SPS parameter
 @"8: Picture parameter set (non-VCL)", // PPS parameter
 @"9: Access unit delimiter (non-VCL)",
 @"10: End of sequence (non-VCL)",
 @"11: End of stream (non-VCL)",
 @"12: Filler data (non-VCL)",
 @"13: Sequence parameter set extension (non-VCL)",
 @"14: Prefix NAL unit (non-VCL)",
 @"15: Subset sequence parameter set (non-VCL)",
 @"16: Reserved (non-VCL)",
 @"17: Reserved (non-VCL)",
 @"18: Reserved (non-VCL)",
 @"19: Coded slice of an auxiliary coded picture without partitioning (non-VCL)",
 @"20: Coded slice extension (non-VCL)",
 @"21: Coded slice extension for depth view components (non-VCL)",
 @"22: Reserved (non-VCL)",
 @"23: Reserved (non-VCL)",
 @"24: STAP-A Single-time aggregation packet (non-VCL)",
 @"25: STAP-B Single-time aggregation packet (non-VCL)",
 @"26: MTAP16 Multi-time aggregation packet (non-VCL)",
 @"27: MTAP24 Multi-time aggregation packet (non-VCL)",
 @"28: FU-A Fragmentation unit (non-VCL)",
 @"29: FU-B Fragmentation unit (non-VCL)",
 @"30: Unspecified (non-VCL)",
 @"31: Unspecified (non-VCL)",
};

@interface LSVideoDecoder()

{
    //解码session
    VTDecompressionSessionRef _mDecoderSession;
    
    //解码format 封装了sps pps
    CMVideoFormatDescriptionRef mCMVideoFormatDescriptionRef;
    
    //sps pps
    uint8_t *_sps;
    uint32_t _spsSize;
    uint8_t *_pps;
    uint32_t _ppsSize;
}

@end

@implementation LSVideoDecoder

- (instancetype)init {
    return [self initWithDelegate:nil];
}

- (instancetype)initWithDelegate:(__weak id<LSVideoDecoderDelegate>)delegate {
    return [self initWithDelegate:delegate decoderType:LSVideoDecoderTypeVTH264];
}

- (instancetype)initWithDelegate:(__weak id<LSVideoDecoderDelegate>)delegate decoderType:(LSVideoDecoderType)decoderType {
    _decoderQueue = dispatch_queue_create("ls_video_decoder_queue", DISPATCH_QUEUE_SERIAL);
    return [self initWithDelegate:delegate decoderType:decoderType videoDecoderQueue:_decoderQueue];
}

- (instancetype)initWithDelegate:(__weak id<LSVideoDecoderDelegate>)delegate decoderType:(LSVideoDecoderType)decoderType videoDecoderQueue:(dispatch_queue_t)decoderQueue {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _decoderQueue = decoderQueue;
        _decoderType = decoderType;
    }
    return self;
}

#pragma mark - Private
- (BOOL)initVideoDecoder {
    switch (self.decoderType) {
        case LSVideoDecoderTypeVTH264:
            return [self initVideoToolBoxDecoder];
            break;
            
        default:
            return NO;
            break;
    }
}

- (BOOL)initVideoToolBoxDecoder {
    if (_mDecoderSession) {
        return YES;
    }
    
    const uint8_t *parameterSetPointers[2] = { _sps, _pps };
    const size_t parameterSetSizes[2] = { _spsSize, _ppsSize };
    
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, &mCMVideoFormatDescriptionRef);
    if (status != noErr) {
        NSLog(@"%s:: create mCMVideoFormatDescriptionRef error:%d", __func__, (int)status);
        return NO;
    }
    
    //获取图像宽高
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(mCMVideoFormatDescriptionRef);
    
    NSDictionary *destinationImageBufferAttributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        (id)kCVPixelBufferWidthKey: @(dimensions.width),
        (id)kCVPixelBufferHeightKey: @(dimensions.height),
        (id)kCVPixelFormatOpenGLCompatibility: @(YES)
    };
    
    //解码回调
    VTDecompressionOutputCallbackRecord callbackRecord;
    callbackRecord.decompressionOutputCallback = decodeOutputDataCallback;
    callbackRecord.decompressionOutputRefCon = (__bridge void *)self;
    
    //创建解码器
    status = VTDecompressionSessionCreate(kCFAllocatorDefault, mCMVideoFormatDescriptionRef, NULL, (__bridge CFDictionaryRef)destinationImageBufferAttributes, &callbackRecord, &_mDecoderSession);
    if (status != noErr) {
        NSLog(@"%s:: VTDecompressionSessionCreate error:%d", __func__, (int)status);
        return NO;
    }
    
    //设置解码线程数量
    VTSessionSetProperty(_mDecoderSession, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)@(1));
    //是否实时解码
    VTSessionSetProperty(_mDecoderSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    
    return YES;
}

- (CVPixelBufferRef)decodeFrame:(uint8_t *)frame size:(uint32_t)size {
    CVPixelBufferRef pixelBuffer = NULL;
    
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL, (void *)frame, size, kCFAllocatorNull, NULL, 0, size, FALSE, &blockBuffer);
    if (status != noErr) {
        NSLog(@"create block buffer error:%d", (int)status);
        CFRelease(blockBuffer);
        return pixelBuffer;
    }
    
    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleSizeArray[] = {size};
    status = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, mCMVideoFormatDescriptionRef, 1, 0, NULL, 1, sampleSizeArray, &sampleBuffer);
    
    if (status != noErr) {
        NSLog(@"create sample buffer error:%d", (int)status);
        CFRelease(sampleBuffer);
        CFRelease(blockBuffer);
        return pixelBuffer;
    }
    
    //VTDecodeFrameFlags 0允许多线程解码
    VTDecodeFrameFlags decodeFlags = 0;
    VTDecodeInfoFlags infoFlagsOut = 0;
    status = VTDecompressionSessionDecodeFrame(_mDecoderSession, sampleBuffer, decodeFlags, &pixelBuffer, &infoFlagsOut);
    if (status != noErr) {
        NSLog(@"VTDecompressionSessionDecodeFrame error:%d", (int)status);
    }
    
    CFRelease(sampleBuffer);
    CFRelease(blockBuffer);
    return pixelBuffer;
}

- (void)decodeNaluData:(NSData *)nalu {
    uint8_t *frame = (uint8_t *)nalu.bytes;
    uint32_t frameSize = (uint32_t)nalu.length;
    
    //frame前4个字节是 start code，第5个字节表示数据类型
    int nalu_type = (frame[4] & 0x1F);
    //将nalu开始码 转为 nalu长度信息
    uint32_t naluSize = (uint32_t)frameSize - 4;
    uint8_t *pNaluSize = (uint8_t *)&naluSize;
    frame[0] = *(pNaluSize + 3);
    frame[1] = *(pNaluSize + 2);
    frame[2] = *(pNaluSize + 1);
    frame[3] = *(pNaluSize);
    
    CVPixelBufferRef pixelBuffer = NULL;
    
    switch (nalu_type) {
        case 0x05://I
            if ([self initVideoDecoder]) {
                pixelBuffer = [self decodeFrame:frame size:frameSize];
            }
            break;
        case 0x07://SPS
            {
                if (_sps) {
                    return;
                }
                _spsSize = frameSize - 4;
                _sps = malloc(_spsSize);
                memcpy(_sps, &frame[4], _spsSize);
                
            }
            break;
        case 0x08://PPS
            {
                if (_pps) {
                    return;
                }
                _ppsSize = frameSize - 4;
                _pps = malloc(_ppsSize);
                memcpy(_pps, &frame[4], _ppsSize);
            }
            break;
            
        default://B 或 P
            if ([self initVideoDecoder]) {
                pixelBuffer = [self decodeFrame:frame size:frameSize];
            }
            break;
            break;
    }
}

- (void)stopDecode {
    VTDecompressionSessionInvalidate(_mDecoderSession);
    CFRelease(mCMVideoFormatDescriptionRef);
    mCMVideoFormatDescriptionRef = NULL;
    if (_sps) {
        free(_sps);
        _sps = NULL;
    }
    if (_pps) {
        free(_pps);
        _pps = NULL;
    }
}

static void decodeOutputDataCallback(void * CM_NULLABLE decompressionOutputRefCon,
                              void * CM_NULLABLE sourceFrameRefCon,
                              OSStatus status,
                              VTDecodeInfoFlags infoFlags,
                              CM_NULLABLE CVImageBufferRef imageBuffer,
                              CMTime presentationTimeStamp,
                              CMTime presentationDuration )
{
    if (status != noErr) {
        //decodeOutputDataCallback error:-12909
//        NSLog(@"%s error:%d", __func__, (int)status);
        return;
    }
    CVPixelBufferRetain(imageBuffer);
    LSVideoDecoder *decoder = (__bridge LSVideoDecoder *)decompressionOutputRefCon;
    if ([decoder.delegate respondsToSelector:@selector(decodeOutputDataCallback:)]) { 
        [decoder.delegate decodeOutputDataCallback:imageBuffer];
    }
}

@end
