//
//  LSAudioCapture.h
//  LSLive
//
//  Created by demo on 2020/6/12.
//  Copyright © 2020 ls. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "LSAudioCaptureConfiguration.h"

/**
 voice_processing_audio_unit.h
 */

NS_ASSUME_NONNULL_BEGIN
@class LSAudioCapture;
@protocol LSAudioCaptureDelegate <NSObject>

@optional
- (void)captureOutput:(LSAudioCapture *)audioCapture audioData:(NSData *)audioData;

@end

@interface LSAudioCapture : NSObject

@property (nonatomic, weak) id<LSAudioCaptureDelegate> delegate;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;

- (instancetype)initWithAudioConfiguration:(LSAudioCaptureConfiguration *)audioConfiguration;

- (void)startCaptureAudio;
- (void)stopCaptureAudio;

@end

NS_ASSUME_NONNULL_END
