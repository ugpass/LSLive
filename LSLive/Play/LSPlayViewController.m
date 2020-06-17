//
//  LSPlayViewController.m
//  LSLive
//
//  Created by demo on 2020/5/5.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSPlayViewController.h"

#import "Masonry.h"

#import <GCDAsyncSocket.h>
#import <GCDAsyncUdpSocket.h>

#import "LSDeviceInfo.h"

//视频解码
#import "LSVideoDecoder.h"

@interface LSPlayViewController ()<GCDAsyncSocketDelegate, GCDAsyncUdpSocketDelegate, LSVideoDecoderDelegate>

@property (nonatomic, strong) GCDAsyncUdpSocket *udp;
@property (nonatomic, strong) GCDAsyncSocket *tcp;

@property (nonatomic, strong) GCDAsyncSocket *clientSocket;

@property (nonatomic, strong) LSVideoDecoder *videoDecoder;

@property (nonatomic, strong) UIImageView *playerView;

@property (nonatomic, strong) NSMutableData *mCacheData;

@end

@implementation LSPlayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"LSPlay", nil);
    self.udp = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_queue_create("ls_udp_queue", DISPATCH_QUEUE_SERIAL)];
    if ([self udpBroadcast]) {
        
        NSString *ipAddress = [LSDeviceInfo getIPAdress];
        NSDictionary *selfInfo = @{@"ipAddress": ipAddress, @"port": @(kTCPPORT)};
        NSData *data= [NSJSONSerialization dataWithJSONObject:selfInfo options:NSJSONWritingPrettyPrinted error:nil];
        
        [self.udp sendData:data toHost:@"255.255.255.255" port:kUDPBROADPORT withTimeout:-1 tag:0];
    }
    
    self.tcp = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_queue_create("ls_tcp_queue", DISPATCH_QUEUE_SERIAL)];
    BOOL ret = [self.tcp acceptOnPort:kTCPPORT error:nil];
    if (!ret) {
        NSLog(@"tcp server accept port failed");
    }
    
    _playerView = [[UIImageView alloc] initWithFrame:CGRectZero];
   [self.view addSubview:_playerView];
   [_playerView mas_makeConstraints:^(MASConstraintMaker *make) {
       make.top.left.bottom.right.mas_equalTo(self.view);
   }];
    
    self.videoDecoder = [[LSVideoDecoder alloc] initWithDelegate:self];
    
    
}

/**
 udp发送广播
 */
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

- (void)parseDataFromTCP:(NSData *)data {
    dispatch_async(dispatch_queue_create("ls_read_data_queue", DISPATCH_QUEUE_SERIAL), ^{
        [self.mCacheData appendData:data];
        NSData *dataLength = [data subdataWithRange:NSMakeRange(0, 4)];
        
        int dataSize = 0;
        
        [dataLength getBytes:&dataSize length:4];
        int totalSize = dataSize + 8;
        while (self.mCacheData.length > 8) {
            if (self.mCacheData.length < totalSize) {
                [self.clientSocket readDataWithTimeout:-1 tag:0];
                break;
            }
            NSData *resultData = [self.mCacheData subdataWithRange:NSMakeRange(8, totalSize)];
            uint8_t *frame = (uint8_t *)resultData.bytes;
            int nalu_type = (frame[4] & 0x1F);
            NSLog(@"----%d\r\n", nalu_type);
//            [self.videoDecoder decodeNaluData:resultData];
            [self.mCacheData replaceBytesInRange:NSMakeRange(0, totalSize) withBytes:nil length:0];
            if (self.mCacheData.length > 8) {
                [self parseDataFromTCP:nil];
            }else {
                [self.clientSocket readDataWithTimeout:-1 tag:0];
            }
        }
    });
}

- (NSMutableData *)mCacheData {
    if (!_mCacheData) {
        _mCacheData = [[NSMutableData alloc] init];
    }
    return _mCacheData;
}

- (void)dealloc {
    [self.videoDecoder stopDecode];
}

#pragma mark - LSVideoDecoderDelegate
- (void)decodeOutputDataCallback:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) {
        return;
    }
    //render pixelBuffer
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        CIContext *tempContext = [CIContext contextWithOptions:nil];
        CGImageRef cgImage = [tempContext createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer))];
        weakSelf.playerView.image = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);
        
        CVPixelBufferRelease(pixelBuffer);
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
    NSLog(@"%s - %p - %ld - %@", __func__, sock, data.length, [[NSString alloc] initWithData:address encoding:NSUTF8StringEncoding]);
}


- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError  * _Nullable)error {
   NSLog(@"%s - %p - %@", __func__, sock, error);
}

#pragma mark - LSTcpDelegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"%s- %p - %p", __func__, sock, newSocket);
    self.clientSocket = newSocket;
    NSLog(@"tcp连接成功：服务器地址：%@ - 端口： %d", newSocket.connectedHost, newSocket.connectedPort);
    [self.clientSocket readDataWithTimeout:-1 tag:0];
}


- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"%s- %p - %@ - %d", __func__, sock, host, port);
}


- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
//    NSLog(@"%s- %p - %ld - %ld", __func__, sock, data.length, tag);
    [self parseDataFromTCP:data];
    
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"%s- %p - %ld", __func__, sock, tag);
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
   NSLog(@"%s- %p - %@", __func__, sock, err);
}


@end
