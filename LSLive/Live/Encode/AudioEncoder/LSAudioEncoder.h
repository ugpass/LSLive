//
//  LSAudioEncoder.h
//  LSLive
//
//  Created by demo on 2020/6/14.
//  Copyright © 2020 ls. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "LSAudioCaptureConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@protocol LSAudioEncoderDelegate <NSObject>
 
- (void)audioEncodeDidOutputData:(NSData *)encodedData;

@end 

@interface LSAudioEncoder : NSObject
{
    NSFileHandle *fileHandele;
    NSString *filePath;
}

//default NO
@property (nonatomic, assign) BOOL writeToFile;

@property (nonatomic, strong) dispatch_queue_t audioEncodeQueue;

@property (nonatomic, weak) id<LSAudioEncoderDelegate> delegate;

- (instancetype)initWithConfiguration:(LSAudioCaptureConfiguration *)configuration;

- (void)startAudioEncoderWithAudioData:(NSData *)audioData;

- (void)stopAudioEncoder;

@end

NS_ASSUME_NONNULL_END
