//
//  LSTcp.m
//  LSLive
//
//  Created by demo on 2020/6/10.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSTcp.h"

@interface LSTcp()<GCDAsyncSocketDelegate>

@property (nonatomic, strong) dispatch_queue_t delegateQueue;


@end

@implementation LSTcp 

- (instancetype)init {
    if (self = [super init]) {
        _delegateQueue = dispatch_queue_create("ls_udp_server_queue", DISPATCH_QUEUE_SERIAL);
        _tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_delegateQueue];
    }
    return self;
}

- (BOOL)connectToHost:(NSString *)host onPort:(uint16_t)port error:(NSError *__autoreleasing  _Nullable *)errPtr {
    if (_tcpSocket) {
        return [_tcpSocket connectToHost:host onPort:port error:errPtr];
    }else {
        return NO;
    }
}

- (void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag {
    if (_tcpSocket) {
        return [_tcpSocket writeData:data withTimeout:timeout tag:tag];
    }else {
        return;
    }
}

#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    if ([self.delegate respondsToSelector:@selector(socket:didAcceptNewSocket:)]) {
        [self.delegate socket:sock didAcceptNewSocket:newSocket];
    }
}


- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    if ([self.delegate respondsToSelector:@selector(socket:didConnectToHost:port:)]) {
        [self.delegate socket:sock didConnectToHost:host port:port];
    }
}


- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if ([self.delegate respondsToSelector:@selector(socket:didReadData:withTag:)]) {
        [self.delegate socket:sock didReadData:data withTag:tag];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    if ([self.delegate respondsToSelector:@selector(socket:didWriteDataWithTag:)]) {
        [self.delegate socket:sock didWriteDataWithTag:tag];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    if ([self.delegate respondsToSelector:@selector(socket:didWriteDataWithTag:)]) {
        [self.delegate socketDidDisconnect:sock withError:err];
    }
}

@end
