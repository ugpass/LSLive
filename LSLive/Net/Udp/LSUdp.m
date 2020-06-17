//
//  LSUdp.m
//  LSLive
//
//  Created by demo on 2020/5/5.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSUdp.h"
@interface LSUdp()<GCDAsyncUdpSocketDelegate>

@property (nonatomic, strong) dispatch_queue_t delegateQueue;

@end


@implementation LSUdp 

- (instancetype)init {
    if (self = [super init]) {
        _delegateQueue = dispatch_queue_create("ls_udp_server_queue", DISPATCH_QUEUE_SERIAL);
        _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:_delegateQueue];

    }
    return self;
}

- (BOOL)enableBroadcast:(BOOL)flag error:(NSError *__autoreleasing  _Nullable *)errPtr {
    if (_udpSocket) {
        return [_udpSocket enableBroadcast:flag error:errPtr];
    }else {
        return NO;
    }
}

- (BOOL)bindToPort:(uint16_t)port error:(NSError **)errPtr {
    if (_udpSocket) {
        return [_udpSocket bindToPort:port error:errPtr];
    }else {
        return NO;
    }
}

- (void)sendData:(NSData *)data
     toHost:(NSString *)host
       port:(uint16_t)port
withTimeout:(NSTimeInterval)timeout
        tag:(long)tag
{
    if (_udpSocket) {
        return [_udpSocket sendData:data toHost:host port:port withTimeout:timeout tag:tag];
    }else {
        return;
    }
}

- (BOOL)receiveOnce:(NSError **)errPtr {
    if (_udpSocket) {
        return [_udpSocket receiveOnce:errPtr];
    }else {
        return NO;
    }
}

#pragma mark - GCDAsyncUdpSocketDelegate
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {
    if ([self.delegate respondsToSelector:@selector(udpSocket:didConnectToAddress:)]) {
        [self.delegate udpSocket:sock didConnectToAddress:address];
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError * _Nullable)error {
    if ([self.delegate respondsToSelector:@selector(udpSocket:didNotConnect:)]) {
        [self.delegate udpSocket:sock didNotConnect:error];
    }
}


- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
    if ([self.delegate respondsToSelector:@selector(udpSocket:didSendDataWithTag:)]) {
        [self.delegate udpSocket:sock didSendDataWithTag:tag];
    }
}


- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError * _Nullable)error {
    if ([self.delegate respondsToSelector:@selector(udpSocket:didNotSendDataWithTag:dueToError:)]) {
        [self.delegate udpSocket:sock didNotSendDataWithTag:tag dueToError:error];
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock
   didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(nullable id)filterContext {
    if ([self.delegate respondsToSelector:@selector(udpSocket:didReceiveData:fromAddress:withFilterContext:)]) {
        [self.delegate udpSocket:sock didReceiveData:data fromAddress:address withFilterContext:filterContext];
    }
}


- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError  * _Nullable)error {
    if ([self.delegate respondsToSelector:@selector(udpSocketDidClose:withError:)]) {
        [self.delegate udpSocketDidClose:sock withError:error];
    }
}


@end
