//
//  LSVideoCapture.m
//  LSLive
//
//  Created by demo on 2020/5/6.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSVideoCapture.h"

@interface LSVideoCapture()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;

@property (nonatomic, strong) dispatch_queue_t captureSessionQueue;

@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;

@property (nonatomic, strong) dispatch_queue_t videoCaptureQueue;

@property (nonatomic, strong) AVCaptureDevice *currentDevice;

@property (nonatomic, strong) AVCaptureConnection *videoConnection;

@property (nonatomic, assign) BOOL isRunning;
 
@property (nonatomic, assign) BOOL willBeRunning;

@property (nonatomic, assign) BOOL hasRetriedOnFatalError;

@end

@implementation LSVideoCapture
{
    FourCharCode _preferredOutputPixelFormat;
    FourCharCode _outputPixelFormat;
    UIDeviceOrientation _orientation;
}

- (instancetype)init {
    return [self initWithDelegate:nil captureSession:[[AVCaptureSession alloc] init]];
}

- (instancetype)initWithDelegate:(__weak id<LSVideoCaptureDelegate>)delegate {
    return [self initWithDelegate:delegate captureSession:[[AVCaptureSession alloc] init]];
}

- (instancetype)initWithDelegate:(__weak id<LSVideoCaptureDelegate>)delegate captureSession:(AVCaptureSession *)captureSession {
    if (self = [super init]) {
        _delegate = delegate;
        _fps = 25;
        _usingFrontCamera = false;
        if (![self setupCaptureSession:captureSession]) {
            return nil;
        }
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        _orientation = UIDeviceOrientationPortrait;
        [center addObserver:self selector:@selector(deviceOrientaionDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
        [center addObserver:self selector:@selector(handleCaptureSessionInterruption:) name:AVCaptureSessionWasInterruptedNotification object:_captureSession];
        [center addObserver:self selector:@selector(handleCaptureSessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:_captureSession];
        [center addObserver:self selector:@selector(handleApplicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:[UIApplication sharedApplication]];
        [center addObserver:self selector:@selector(handleCaptureSessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:_captureSession];
        [center addObserver:self selector:@selector(handleCaptureSessionDidStartRunning:) name:AVCaptureSessionDidStartRunningNotification object:_captureSession];
        [center addObserver:self selector:@selector(handleCaptureSessionDidStopRunning:) name:AVCaptureSessionDidStopRunningNotification object:_captureSession];
    }
    return self;
}

- (BOOL)setupCaptureSession:(AVCaptureSession *)captureSession {
    NSAssert(_captureSession == nil, @"Setup capture session called twice");
    _captureSession = captureSession;
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        _captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    }
    _captureSession.usesApplicationAudioSession = NO;
    [self setupDevice];
    [self setupVideoDataInput];
    [self setupVideoDataOutput];
    if (![_captureSession canAddOutput:_videoDataOutput]) {
        return NO;
    }
    [_captureSession addOutput:_videoDataOutput];
    _videoDataOutput.videoSettings = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    [self fixVideoOrientation];
    return YES;
}

- (void)setupDevice {
    AVCaptureDevice *inputCamera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (self.usingFrontCamera) {
            if ([device position] == AVCaptureDevicePositionFront) {
                inputCamera = device;
            }
        }else {
            if ([device position] == AVCaptureDevicePositionBack) {
                inputCamera = device;
            }
        }
        
    }
    _currentDevice = inputCamera;
}

- (void)setupVideoDataOutput {
    NSAssert(_videoDataOutput == nil, @"Setup video data output called twice");
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
     
    videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    [videoDataOutput setSampleBufferDelegate:self queue:self.videoCaptureQueue];
    
    _videoDataOutput = videoDataOutput;
}

- (void)fixVideoOrientation {
    //需要在addOutput 和addInput之后
        _videoConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([_videoConnection isVideoOrientationSupported]) {
            //设置videoOrientation 为竖屏状态，与deviceOriention不一样 ，否则竖屏采集到的数据存储为h264播放 为横屏
            switch (_orientation) {
                case UIDeviceOrientationPortrait:
                    [_videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
                    break;
                 case UIDeviceOrientationLandscapeLeft:
                    [_videoConnection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
                    break;
                case UIDeviceOrientationLandscapeRight:
                    [_videoConnection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
                    break;
                case UIDeviceOrientationPortraitUpsideDown:
                    [_videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
                    break;
                default:
                    break;
            }
            
            
            //默认
    //        [connection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
        }
}

+ (NSSet<NSNumber *> *)supportedPixelFormats {
    return [NSSet setWithObjects:
            @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
            @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
            @(kCVPixelFormatType_32BGRA),
            @(kCVPixelFormatType_32ARGB), nil];
}

- (dispatch_queue_t)captureSessionQueue {
    if (!_captureSessionQueue) {
        _captureSessionQueue = dispatch_queue_create("ls_capture_session_queue", DISPATCH_QUEUE_SERIAL);
    }
    return _captureSessionQueue;
}


- (dispatch_queue_t)videoCaptureQueue {
    if (!_videoCaptureQueue) {
        _videoCaptureQueue = dispatch_queue_create("ls_video_capture_queue", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_videoCaptureQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    }
    return _videoCaptureQueue;
}

#pragma mark - startCapture
- (void)startCapture {
    [self startCaptureWithFps:self.fps];
}

- (void)startCaptureWithFps:(NSInteger)fps {
    _willBeRunning = YES;
    _fps = fps;
    dispatch_async(self.captureSessionQueue, ^{
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        
        NSError *error = nil;
        if (![self.currentDevice lockForConfiguration:&error]) {
            NSLog(@"%s-error=%@", __func__, error.description);
            self.willBeRunning = NO;
            return;
        }
        
        [self updateOrientation];
        //这里是抄webrtc的 暂时没有用上
        //        [self updateDeviceCaptureFormat:format fps:fps];
        //        [self updateVideoDataOutputPixelFormat:format];
        [self.captureSession startRunning];
        self.isRunning = YES;
    });
}

#pragma mark - stopCapture
//stopRunning may not be called between calls to beginConfiguration and commitConfiguration
- (void)stopCaptureWithCompletionHandler:(nullable void (^)(void))completionHandler {
    _willBeRunning = NO;
    dispatch_async(self.captureSessionQueue, ^{
        for (AVCaptureDeviceInput *input in self.captureSession.inputs) {
            [self.captureSession removeInput:input];
        }
        [self.captureSession stopRunning];
        [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
        if (completionHandler) {
            completionHandler();
        }
    });
}

#pragma mark - switchCamera
- (void)switchCamera {
    _usingFrontCamera = !_usingFrontCamera;
    [self setupDevice];
    [self reconfigurationInput];
    [self fixVideoOrientation];
    [self startCapture];
}

- (void)setupVideoDataInput {
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:_currentDevice error:&error];
    if (!input) {
        return;
    }
    
    for (AVCaptureDeviceInput *oldInput in [_captureSession.inputs copy]) {
        [_captureSession removeInput:oldInput];
    }
    if ([_captureSession canAddInput:input]) {
        [_captureSession addInput:input];
    }else {
        NSLog(@"%s-addInput error=%@", __func__, error.description);
    }
    
}

- (void)reconfigurationInput {
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:_currentDevice error:&error];
    if (!input) {
        return;
    }
    [_captureSession beginConfiguration];
    for (AVCaptureDeviceInput *oldInput in [_captureSession.inputs copy]) {
        [_captureSession removeInput:oldInput];
    }
    if ([_captureSession canAddInput:input]) {
        [_captureSession addInput:input];
    }else {
        NSLog(@"%s-addInput error=%@", __func__, error.description);
    }
    [_captureSession commitConfiguration];
}

- (void)updateDeviceCaptureFormat:(AVCaptureDeviceFormat *)format
                              fps:(NSInteger)fps {
    _currentDevice.activeFormat = format;
    _currentDevice.activeVideoMinFrameDuration = CMTimeMake(1, (int32_t)fps);
}

- (void)updateVideoDataOutputPixelFormat:(AVCaptureDeviceFormat *)format{
    FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(format.formatDescription);
    if (![[[self class] supportedPixelFormats] containsObject:@(mediaSubType)]) {
        mediaSubType = _preferredOutputPixelFormat;
    }
    if (mediaSubType != _outputPixelFormat) {
        _outputPixelFormat = mediaSubType;
        _videoDataOutput.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(mediaSubType)};
    }
}


- (void)updateOrientation {
    _orientation = [UIDevice currentDevice].orientation;
    [self fixVideoOrientation];
}

#pragma mark - UIDeviceOrientationDidChangeNotification
- (void)deviceOrientaionDidChange:(NSNotification *)noti {
    NSLog(@"%s---%ld", __func__, (long)_orientation);
    dispatch_async(self.captureSessionQueue, ^{
        [self updateOrientation];
    });
}

#pragma mark - AVCaptureSessionWasInterruptedNotification
- (void)handleCaptureSessionInterruption:(NSNotification *)noti {
    NSString *reasonString = nil;
    NSNumber *reason = noti.userInfo[AVCaptureSessionInterruptionReasonKey];
    if ([reason intValue]) {
        switch (reason.intValue) {
            case AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableInBackground:
                reasonString = @"VideoDeviceNotAvailableInBackground";
                break;
            case AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient:
                reasonString = @"VideoDeviceInUseByAnotherClient";
                break;
            case AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient:
                reasonString = @"AudioDeviceInUseByAnotherClient";
                break;
            case AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps:
                reasonString = @"VideoDeviceNotAvailableWithMultipleForegroundApps";
                break;
            default:
                break;
        }
    }
    NSLog(@"%s- %@", __func__, reasonString);
}

#pragma mark - handleCaptureSessionInterruptionEnded
- (void)handleCaptureSessionInterruptionEnded:(NSNotification *)noti {
    NSLog(@"%s", __func__);
}

#pragma mark - handleApplicationDidBecomeActive
- (void)handleApplicationDidBecomeActive:(NSNotification *)noti {
    dispatch_async(self.captureSessionQueue, ^{
        if (self.isRunning && !self.captureSession.isRunning) {
            NSLog(@"restart capture session on active.");
            [self.captureSession startRunning];
        }
    });
}

#pragma mark -
- (void)handleCaptureSessionRuntimeError:(NSNotification *)noti {
    NSError *error = [noti.userInfo objectForKey:AVCaptureSessionErrorKey];
    NSLog(@"%s- %@", __func__, error);
    dispatch_async(self.captureSessionQueue, ^{
        if (error.code == AVErrorMediaServicesWereReset) {
            [self handleNonFatalError];
        }else {
            [self handleFatalError];
        }
    });
}

- (void)handleFatalError {
    dispatch_async(self.captureSessionQueue, ^{
        if (!self.hasRetriedOnFatalError) {
            [self handleNonFatalError];
            self.hasRetriedOnFatalError = YES;
        }else {
            NSLog(@"retry start with error");
        }
    });
}

- (void)handleNonFatalError {
    dispatch_async(self.captureSessionQueue, ^{
        NSLog(@"restart capture session after error");
        if (self.isRunning) {
            [self.captureSession startRunning];
        }
    });
}

#pragma mark - AVCaptureSessionDidStartRunningNotification
- (void)handleCaptureSessionDidStartRunning:(NSNotification *)noti {
    dispatch_async(self.captureSessionQueue, ^{
        //start with no error
        self.hasRetriedOnFatalError = NO;
    });
}

#pragma mark - AVCaptureSessionDidStopRunningNotification
- (void)handleCaptureSessionDidStopRunning:(NSNotification *)noti {
    NSLog(@"%s", __func__);
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (_videoConnection == connection) {
        [self.delegate didCaptureSampleBuffer:sampleBuffer];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"%s", __func__);
}
@end
