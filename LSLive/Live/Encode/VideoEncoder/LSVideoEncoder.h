//
//  LSVideoEncoder.h
//  LSLive
//
//  Created by demo on 2020/6/14.
//  Copyright © 2020 ls. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    LSVideoEncoderTypeVTH264,//VideoToolBox H264
} LSVideoEncoderType;

///编码回调
@protocol LSVideoEncoderDelegate <NSObject>

@optional
//encodedData has start code
- (void)videoEncodeDidOutputData:(NSData *)encodedData isKeyFrame:(BOOL)isKeyFrame;

@end

@interface LSVideoEncoder : NSObject
{
    NSFileHandle *fileHandele;
    NSString *filePath;
}

//default NO
@property (nonatomic, assign) BOOL writeToFile;

@property (nonatomic, strong) dispatch_queue_t encoderQueue;

//default LSVideoEncoderTypeVTH264
@property (nonatomic, assign) LSVideoEncoderType encoderType;

@property (nonatomic, weak) id<LSVideoEncoderDelegate> delegate;
 

- (void)startVideoEncoderSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)stopVideoEncoder;

@end

NS_ASSUME_NONNULL_END
