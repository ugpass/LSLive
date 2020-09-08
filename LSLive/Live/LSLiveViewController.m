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

#import <GCDAsyncSocket.h>
#import <GCDAsyncUdpSocket.h>

@interface LSLiveViewController ()<LSVideoCaptureDelegate, LSAudioCaptureDelegate, LSVideoEncoderDelegate, GCDAsyncUdpSocketDelegate, GCDAsyncSocketDelegate, LSVideoDecoderDelegate, LSAudioEncoderDelegate>

//视频
@property (nonatomic, strong) LSVideoCapture *capture;

@property (nonatomic, assign) BOOL usingFrontCamera;

@property (nonatomic, strong) LSCameraPreviewView *previewView;

@property (nonatomic, strong) LSH264VideoEncoder *videoEncoder;

@property (nonatomic, strong) GCDAsyncUdpSocket *udp;

@property (nonatomic, strong) GCDAsyncSocket *tcp;

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
    _playerView.backgroundColor = [UIColor redColor];
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
    
    self.udp = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_queue_create("ls_udp_queue", DISPATCH_QUEUE_SERIAL)];
    if ([self udpBroadcast]) {
        NSError *error = nil;
        [self.udp receiveOnce:&error];
        if (error) {
            NSLog(@"receiveOnce error=%@", error);
        } 
    }
    
    self.tcp = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_queue_create("ls_tcp_queue", DISPATCH_QUEUE_SERIAL)];
    
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

- (BOOL)udpBroadcast {
    self.udp.delegate = self;
    NSError *error = nil;
    [self.udp enableBroadcast:YES error:&error];
    if (error) {
        NSLog(@"enableBroadcast error:%@", error);
        return NO;
    }
    
    [self.udp bindToPort:kUDPBROADPORT error:&error];
    if (error) {
        NSLog(@"bindToPort error:%@", error);
        return NO;
    }
    return YES;
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
    
    [self.previewView removeFromSuperview];
    self.previewView = nil;
    [self.videoDecoder stopDecode];
    [self.videoEncoder stopVideoEncoder];
    [self.capture stopCaptureWithCompletionHandler:nil];
    NSLog(@"%s", __func__);
}

/**
 send encoded data by tcp
 tcp 需要处理粘包 拆包的问题
 发送方 在数据头部加上数据长度
 接收方 解析数据长度，取数据
 */
- (void)sendEncodedDataByTCP:(NSData *)encodedData dataType:(int)dataType {
    static long long tcpWTag = 0;
    if (self.tcp && self.tcp.isConnected) {
        dispatch_async(dispatch_queue_create("ls_write_data_queue", DISPATCH_QUEUE_SERIAL), ^{
            NSMutableData *mData = [NSMutableData data];
            // 1.计算数据总长度 data
            unsigned int dataLength = 4 + 4 + (int)encodedData.length;
            // 将长度转成data
            NSData *lengthData = [NSData dataWithBytes:&dataLength length:4];
            
            // mData 拼接长度data
            [mData appendData:lengthData];
            
            NSData *typeData = [NSData dataWithBytes:&dataType length:4];
            [mData appendData:typeData];
            
            // 3.最后拼接真正的数据data
            [mData appendData:encodedData];
            [self.tcp writeData:mData withTimeout:-1 tag:tcpWTag++];
        });
    }
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
    //    [self sendEncodedDataByTCP:encodedData dataType:isKeyFrame?1:0];
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

#pragma mark - LSUdpDelegate
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {
    NSLog(@"%s - %p - %@", __func__, sock, [[NSString alloc] initWithData:address encoding:NSUTF8StringEncoding]);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError * _Nullable)error {
    NSLog(@"%s - %p - %@", __func__, sock, error);
}


- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
    NSLog(@"%s - %p - %ld", __func__, sock, tag);
}


- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError * _Nullable)error {
     NSLog(@"%s - %p - %ld - %@", __func__, sock, tag, error);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock
   didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(nullable id)filterContext {
    NSLog(@"%s - %p - %ld - %@", __func__, sock, data.length, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    NSError *err = nil;
    NSDictionary *dictionary =[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&err];
    if (err) {
        NSLog(@"parse receive data error=%@", err);
        return;
    }
    
    NSString *ipAddress = [dictionary objectForKey:@"ipAddress"];
    uint16_t port = [[dictionary objectForKey:@"port"] intValue];
     
    [self.tcp connectToHost:ipAddress onPort:port error:&err];
    if (err) {
        NSLog(@"tcp connect to host error=%@", err);
        return;
    }
}


- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError  * _Nullable)error {
   NSLog(@"%s - %p - %@", __func__, sock, error);
}

#pragma mark - LSTcpDelegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"%s- %p - %p", __func__, sock, newSocket);
}


- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"%s- %p - %@ - %d", __func__, sock, host, port);
    [self.tcp readDataWithTimeout:-1 tag:0];
}


- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"%s- %p - %ld - %ld", __func__, sock, data.length, tag);
    [self.tcp readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"%s- %p - %ld", __func__, sock, tag);
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
   NSLog(@"%s- %p - %@", __func__, sock, err);
}

@end
