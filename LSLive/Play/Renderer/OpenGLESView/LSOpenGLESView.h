//
//  LSOpenGLESView.h
//  LSLive
//
//  Created by demo on 2020/9/7.
//  Copyright © 2020 ls. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2//glext.h>
NS_ASSUME_NONNULL_BEGIN

@interface LSOpenGLESView : UIView

- (void)startRenderWithSamplerBuffer:(CVPixelBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
