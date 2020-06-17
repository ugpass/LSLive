//
//  LSCameraPreviewView.m
//  LSLive
//
//  Created by demo on 2020/5/7.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSCameraPreviewView.h"

@implementation LSCameraPreviewView

+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureVideoPreviewLayer *)previewLayer {
    return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self addOrientationObserver];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self addOrientationObserver];
    }
    return self;
}

- (void)orientaionChanged:(NSNotification *)noti {
    [self setCorrectVideoOrientation];
}

- (void)addOrientationObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientaionChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)removeOrientaionObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)setCaptureSession:(AVCaptureSession *)captureSession {
    if (_captureSession == captureSession) {
        return;
    }
    [LSDispatcher dispatchAsyncOnType:LSDispatcherTypeMain block:^{
        AVCaptureVideoPreviewLayer *previewLayer = [self previewLayer];
        [LSDispatcher dispatchAsyncOnType:LSDispatcherTypeCaptureSession block:^{
            previewLayer.session = captureSession;
        }];
        [self setCorrectVideoOrientation];
    }];
}

- (void)setCorrectVideoOrientation {
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    AVCaptureVideoPreviewLayer *previewLayer = [self previewLayer];
    if (previewLayer.connection.isVideoOrientationSupported) {
        if (deviceOrientation == UIDeviceOrientationPortraitUpsideDown) {
            previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        }else if (deviceOrientation == UIDeviceOrientationLandscapeRight) {
            previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
        }else if (deviceOrientation == UIDeviceOrientationLandscapeLeft) {
            previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
        }else if (deviceOrientation == UIDeviceOrientationPortrait) {
            previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        }
    }
}

- (void)dealloc {
    AVCaptureVideoPreviewLayer *previewLayer = [self previewLayer];
    previewLayer.session = nil;
    [self removeOrientaionObserver];
    NSLog(@"%s", __func__);
}


@end
