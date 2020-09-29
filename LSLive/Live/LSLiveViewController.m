//
//  LSLiveViewController.m
//  LSLive
//
//  Created by demo on 2020/5/5.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSLiveViewController.h"

#import <MetalKit/MetalKit.h>

#import "Masonry.h"

//视频采集
#import "LSVideoCapture.h"
#import "LSCameraPreviewView.h"

//视频编码
#import "LSH264VideoEncoder.h"

//视频解码
#import "LSVideoDecoder.h"


//音频采集
#import "LSAudioCapture.h"

//音频编码
#import "LSAudioEncoder.h"

//Metal显示视图
#import "LSMetalView.h"

//OpenGL ES显示视图
#import "LSOpenGLESView.h"


@interface LSLiveViewController ()<LSVideoCaptureDelegate, LSAudioCaptureDelegate, LSVideoEncoderDelegate, LSVideoDecoderDelegate, LSAudioEncoderDelegate>

//视频
@property (nonatomic, strong) LSVideoCapture *capture;

@property (nonatomic, assign) BOOL usingFrontCamera;

@property (nonatomic, strong) LSCameraPreviewView *previewView;

@property (nonatomic, strong) LSH264VideoEncoder *videoEncoder;

@property (nonatomic, strong) LSOpenGLESView *playerView;

@property (nonatomic, strong) LSVideoDecoder *videoDecoder;

//音频
@property (nonatomic, strong) LSAudioCapture *audioCapture;

@property (nonatomic, strong) LSAudioEncoder *audioEncoder;

@end

@implementation LSLiveViewController
{
    UIButton *_switchCameraBtn;
}

- (void)setupUI {
    
    _previewView = [[LSCameraPreviewView alloc] initWithFrame:CGRectZero];
    
    [self.view addSubview:_previewView];
    
    [_previewView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.bottom.right.mas_equalTo(@0);
    }];
    
    
    _switchCameraBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_switchCameraBtn setBackgroundImage:[UIImage imageNamed:@"camera.png"] forState:UIControlStateNormal];
    [self.view addSubview:_switchCameraBtn];
    [_switchCameraBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(40, 40));
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.bottom.mas_equalTo(@(-60));
    }]; 
    [_switchCameraBtn addTarget:self action:@selector(switchCamera) forControlEvents:UIControlEventTouchUpInside];
 
    _playerView = [[LSOpenGLESView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_playerView];
    [_playerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.mas_equalTo(@80);
        make.width.mas_equalTo(@100);
        make.height.mas_equalTo(@200);
    }];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"LSLive", nil);
    
    [self setupUI];
    
    self.videoEncoder = [[LSH264VideoEncoder alloc] init];
    self.videoEncoder.delegate = self;
    self.videoEncoder.writeToFile = YES;
    self.videoDecoder = [[LSVideoDecoder alloc] initWithDelegate:self];

    
    self.audioEncoder = [[LSAudioEncoder alloc] initWithConfiguration:[LSAudioCaptureConfiguration defaultAudioConfiguration]];
    self.audioEncoder.delegate = self;
    self.audioEncoder.writeToFile = YES;
    
    self.audioCapture = [[LSAudioCapture alloc] initWithAudioConfiguration:[LSAudioCaptureConfiguration defaultAudioConfiguration]];
    self.audioCapture.delegate = self;
    [self.audioCapture startCaptureAudio];
    
    //开始采集视频
    [self startCapture]; 
//    [[LSAudioUnitManager shareInstance] startRecordAndPlay];
    //开始直播 编码音视频
    //发送广播
}


- (void)switchCamera {
    [self.capture switchCamera];
}

- (void)startCapture {
    [self.capture startCapture];
}

- (LSVideoCapture *)capture {
    if (!_capture) {
        _capture = [[LSVideoCapture alloc] initWithDelegate:self];
        self.previewView.captureSession = _capture.captureSession;
    }
    return _capture;
}

- (void)dealloc {
    [self.audioCapture stopCaptureAudio];
    [self.videoDecoder stopDecode];
    [self.videoEncoder stopVideoEncoder];
    [self.capture stopCaptureWithCompletionHandler:nil];
    
    [self.playerView removeFromSuperview];
    self.playerView = nil;
    
    [self.previewView removeFromSuperview];
    self.previewView = nil;
    
    NSLog(@"%s", __func__);
}



#pragma mark - LSVideoCaptureDelegate
- (void)didCaptureSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    //可以把采集到的数据给美颜处理后的回调中 编码
    
    //直接编码
    [self.videoEncoder startVideoEncoderSampleBuffer:sampleBuffer];
}

#pragma mark - LSAudioCaptureDelegate
- (void)captureOutput:(LSAudioCapture *)audioCapture audioData:(NSData *)audioData {
    [self.audioEncoder startAudioEncoderWithAudioData:audioData];
}

#pragma mark - LSVideoEncoderDelegate
- (void)videoEncodeDidOutputData:(NSData *)encodedData isKeyFrame:(BOOL)isKeyFrame {
        [self.videoDecoder decodeNaluData:encodedData];
}

#pragma mark - LSAudioEncoderDelegate
- (void)audioEncodeDidOutputData:(NSData *)encodedData {
//    NSLog(@"audioEncodeDidOutputData dataLength:%ld", encodedData.length);
    
}


#pragma mark - LSVideoDecoderDelegate
- (void)decodeOutputDataCallback:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) {
        return;
    }
    //render pixelBuffer
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.playerView startRenderWithSamplerBuffer:pixelBuffer];
    });
    
}



@end
