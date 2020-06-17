//
//  LSUdp.h
//  LSLive
//
//  Created by demo on 2020/5/5.
//  Copyright © 2020 ls. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GCDAsyncUdpSocket.h>

NS_ASSUME_NONNULL_BEGIN

@protocol  LSUdpDelegate<NSObject>

@optional
/**
 * By design, UDP is a connectionless protocol, and connecting is not needed.
 * However, you may optionally choose to connect to a particular host for reasons
 * outlined in the documentation for the various connect methods listed above.
 *
 * This method is called if one of the connect methods are invoked, and the connection is successful.
**/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address;

/**
 * By design, UDP is a connectionless protocol, and connecting is not needed.
 * However, you may optionally choose to connect to a particular host for reasons
 * outlined in the documentation for the various connect methods listed above.
 *
 * This method is called if one of the connect methods are invoked, and the connection fails.
 * This may happen, for example, if a domain name is given for the host and the domain name is unable to be resolved.
**/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError * _Nullable)error;

/**
 * Called when the datagram with the given tag has been sent.
**/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag;

/**
 * Called if an error occurs while trying to send a datagram.
 * This could be due to a timeout, or something more serious such as the data being too large to fit in a sigle packet.
**/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError * _Nullable)error;

/**
 * Called when the socket has received the requested datagram.
**/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
                                             fromAddress:(NSData *)address
                                       withFilterContext:(nullable id)filterContext;

/**
 * Called when the socket is closed.
**/
- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError  * _Nullable)error;

@end

@interface LSUdp : NSObject

@property (nonatomic, weak) id<LSUdpDelegate> delegate;

@property (nonatomic, strong) GCDAsyncUdpSocket *udpSocket; 

- (BOOL)enableBroadcast:(BOOL)flag error:(NSError **)errPtr;

- (BOOL)bindToPort:(uint16_t)port error:(NSError **)errPtr;

- (void)sendData:(NSData *)data
     toHost:(NSString *)host
       port:(uint16_t)port
withTimeout:(NSTimeInterval)timeout
             tag:(long)tag;

- (BOOL)receiveOnce:(NSError **)errPtr;
@end

NS_ASSUME_NONNULL_END
