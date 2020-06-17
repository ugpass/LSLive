//
//  LSVideoEncoder.m
//  LSLive
//
//  Created by demo on 2020/6/14.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSVideoEncoder.h"

@implementation LSVideoEncoder

- (instancetype)init {
    if (self = [super init]) {
        _encoderQueue = dispatch_queue_create("ls_video_encoder_queue", DISPATCH_QUEUE_SERIAL);
        _encoderType = LSVideoEncoderTypeVTH264;
        _writeToFile = NO; 
    }
    return self;
}


#pragma mark - setter

- (void)setWriteToFile:(BOOL)writeToFile {
    if (_writeToFile != writeToFile) {
        _writeToFile = writeToFile;
        if (_writeToFile == YES) {
            filePath = [NSHomeDirectory() stringByAppendingPathComponent:@"/Documents/LSVideo.h264"];

            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            
            BOOL createFile = [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
            if (!createFile) {
                NSLog(@"create file failed");
            } else {
                NSLog(@"create file success");
            }
            NSLog(@"filePaht = %@",filePath);
            fileHandele = [NSFileHandle fileHandleForWritingAtPath:filePath];
        }
    }
}


@end
