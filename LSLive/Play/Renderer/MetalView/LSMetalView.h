//
//  LSMetalView.h
//  LSLive
//
//  Created by demo on 2020/9/3.
//  Copyright © 2020 ls. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LSMetalView : MTKView<MTKViewDelegate>

- (void)startRenderWithSamplerBuffer:(CVPixelBufferRef)sampleBuffer;


@end

NS_ASSUME_NONNULL_END
