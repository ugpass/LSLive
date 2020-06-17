//
//  LSDispatcher.m
//  LSLive
//
//  Created by demo on 2020/5/7.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSDispatcher.h"

static dispatch_queue_t kAudioSessionQueue = nil;
static dispatch_queue_t kCaptureSessionQueue = nil;

@implementation LSDispatcher

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kCaptureSessionQueue = dispatch_queue_create("ls_video_capture_session_queue", DISPATCH_QUEUE_SERIAL);
        kAudioSessionQueue = dispatch_queue_create("ls_audio_session_queue", DISPATCH_QUEUE_SERIAL);
    });
}

+ (void)dispatchAsyncOnType:(LSDispatcherType)dispatchType block:(dispatch_block_t)block {
    dispatch_queue_t queue = [self dispatchQueueForType:dispatchType];
    dispatch_async(queue, block);
}

+ (dispatch_queue_t)dispatchQueueForType:(LSDispatcherType)dispatchType {
    switch (dispatchType) {
        case LSDispatcherTypeMain:
            return dispatch_get_main_queue();
        case LSDispatcherTypeCaptureSession:
            return kCaptureSessionQueue;
        case LSDispatcherTypeAudioSession:
            return kAudioSessionQueue;
    }
    
}
@end
