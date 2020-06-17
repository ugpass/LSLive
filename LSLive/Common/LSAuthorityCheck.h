//
//  LSUtil.h
//  LSLive
//
//  Created by demo on 2020/5/5.
//  Copyright © 2020 ls. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LSAuthorityModel : NSObject

@property (nonatomic, assign) BOOL isAllowed;
@property (nonatomic, copy) NSString *message;

@end

@interface LSAuthorityCheck : NSObject
+ (LSAuthorityModel *)cameraAuthority;
@end

NS_ASSUME_NONNULL_END
