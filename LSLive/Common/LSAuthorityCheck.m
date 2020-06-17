//
//  LSUtil.m
//  LSLive
//
//  Created by demo on 2020/5/5.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSAuthorityCheck.h"

@implementation LSAuthorityModel

@end

@implementation LSAuthorityCheck

+ (LSAuthorityModel *)cameraAuthority{
    LSAuthorityModel *model = [[LSAuthorityModel alloc] init];
    NSString *mediaType = AVMediaTypeVideo;//读取媒体类型
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];//读取设备授权状态
    switch (authStatus) {
        case AVAuthorizationStatusNotDetermined:
        {
            model.isAllowed = NO;
            model.message = @"NotDetermined";
        }
            break;
        case AVAuthorizationStatusRestricted:
        {
            model.isAllowed = NO;
            model.message = @"Restricted";
        }
            break;
        case AVAuthorizationStatusDenied:
        {
            model.isAllowed = NO;
            model.message = @"Denied";
        }
            break;
        case AVAuthorizationStatusAuthorized:
        {
            model.isAllowed = YES;
            model.message = @"Authorized";
        }
            break;
        default:
            break;
    }
    return model;
}

@end
