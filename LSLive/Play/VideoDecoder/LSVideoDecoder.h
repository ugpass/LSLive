//
//  LSVideoDecoder.h
//  LSLive
//
//  Created by demo on 2020/6/7.
//  Copyright © 2020 ls. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

typedef enum : NSUInteger {
    LSVideoDecoderTypeVTH264,//VideoToolBox H264
} LSVideoDecoderType;

NS_ASSUME_NONNULL_BEGIN

///解码回调
@protocol LSVideoDecoderDelegate <NSObject> 

@optional

- (void)decodeOutputDataCallback:(CVPixelBufferRef)pixelBuffer;

@end

@interface LSVideoDecoder : NSObject

@property (nonatomic, weak) id<LSVideoDecoderDelegate> delegate;

@property (nonatomic, assign) LSVideoDecoderType decoderType;

@property (nonatomic, strong) dispatch_queue_t decoderQueue;

- (instancetype)init;

- (instancetype)initWithDelegate:(nullable __weak id<LSVideoDecoderDelegate>)delegate;

///encoderType default LSVideoEncoderTypeVTH264
- (instancetype)initWithDelegate:(nullable __weak id<LSVideoDecoderDelegate>)delegate decoderType:(LSVideoDecoderType)decoderType;

- (instancetype)initWithDelegate:(nullable __weak id<LSVideoDecoderDelegate>)delegate decoderType:(LSVideoDecoderType)decoderType videoDecoderQueue:(dispatch_queue_t)decoderQueue;

- (void)decodeNaluData:(NSData *)nalu;

- (void)stopDecode;

@end

NS_ASSUME_NONNULL_END
