//
//  LSDispatcher.h
//  LSLive
//
//  Created by demo on 2020/5/7.
//  Copyright © 2020 ls. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef enum : NSUInteger {
    LSDispatcherTypeMain,
    LSDispatcherTypeCaptureSession,
    LSDispatcherTypeAudioSession,
} LSDispatcherType;

@interface LSDispatcher : NSObject
+ (void)dispatchAsyncOnType:(LSDispatcherType)dispatchType block:(dispatch_block_t)block;
@end

NS_ASSUME_NONNULL_END
