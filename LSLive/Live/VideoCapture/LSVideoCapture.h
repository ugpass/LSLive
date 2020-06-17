//
//  LSVideoCapture.h
//  LSLive
//
//  Created by demo on 2020/5/6.
//  Copyright © 2020 ls. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LSVideoCaptureDelegate <NSObject>

- (void)didCaptureSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

@interface LSVideoCapture : NSObject

@property (readonly, nonatomic)AVCaptureSession *captureSession;

//default 25
@property (nonatomic, assign) NSInteger fps;

//default false
@property (nonatomic, assign) BOOL usingFrontCamera;

@property (nonatomic, weak) id<LSVideoCaptureDelegate> delegate;

- (instancetype)initWithDelegate:(__weak id<LSVideoCaptureDelegate>)delegate;

- (void)startCapture;

- (void)stopCaptureWithCompletionHandler:(nullable void (^)(void))completionHandler;
 
- (void)switchCamera;
@end

NS_ASSUME_NONNULL_END
