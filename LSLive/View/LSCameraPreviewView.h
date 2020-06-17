//
//  LSCameraPreviewView.h
//  LSLive
//
//  Created by demo on 2020/5/7.
//  Copyright © 2020 ls. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LSCameraPreviewView : UIView
@property (nonatomic, strong) AVCaptureSession *captureSession;
@end

NS_ASSUME_NONNULL_END
