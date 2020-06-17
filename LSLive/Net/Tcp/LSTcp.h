//
//  LSTcp.h
//  LSLive
//
//  Created by demo on 2020/6/10.
//  Copyright © 2020 ls. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GCDAsyncSocket.h>

NS_ASSUME_NONNULL_BEGIN

@protocol  LSTcpDelegate<NSObject>

@optional
/**
 * Called when a socket accepts a connection.
 * Another socket is automatically spawned to handle it.
 *
 * You must retain the newSocket if you wish to handle the connection.
 * Otherwise the newSocket instance will be released and the spawned connection will be closed.
 *
 * By default the new socket will have the same delegate and delegateQueue.
 * You may, of course, change this at any time.
**/
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket;

/**
 * Called when a socket connects and is ready for reading and writing.
 * The host parameter will be an IP address, not a DNS name.
**/
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port;

/**
 * Called when a socket has completed reading the requested data into memory.
 * Not called if there is an error.
**/
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag;

/**
 * Called when a socket has completed writing the requested data. Not called if there is an error.
**/
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag;

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err;
@end

@interface LSTcp : NSObject

@property (nonatomic, weak) id<LSTcpDelegate> delegate;

@property (nonatomic, strong) GCDAsyncSocket *tcpSocket;

- (BOOL)connectToHost:(NSString *)host onPort:(uint16_t)port error:(NSError **)errPtr;

- (void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag;
@end

NS_ASSUME_NONNULL_END
