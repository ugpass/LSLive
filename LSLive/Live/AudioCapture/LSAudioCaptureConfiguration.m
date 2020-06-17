//
//  LSAudioCaptureConfiguration.m
//  LSLive
//
//  Created by demo on 2020/6/12.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSAudioCaptureConfiguration.h"

@implementation LSAudioCaptureConfiguration

+ (instancetype)defaultAudioConfiguration {
    LSAudioCaptureConfiguration *audioConfig = [LSAudioCaptureConfiguration defaultAudioConfigurationForQuality:LSAudioQuality_Default];
    return audioConfig;
}

+ (instancetype)defaultAudioConfigurationForQuality:(LSAudioQuality)audioQuality {
    LSAudioCaptureConfiguration *audioConfig = [[LSAudioCaptureConfiguration alloc] init];
    audioConfig.numberOfChannels = 2;
    switch (audioQuality) {
        case LSAudioQuality_Low:
        {
            audioConfig.audioBitrate = audioConfig.numberOfChannels == 1 ? LSAudioBitrate_32Kbps : LSAudioBitrate_64Kbps;
            audioConfig.audioSampleRate = LSAudioSampleRate_16000Hz;
        }
            break;
        case LSAudioQuality_Medium:
        {
            audioConfig.audioBitrate = LSAudioBitrate_96Kbps;
            audioConfig.audioSampleRate = LSAudioSampleRate_44100Hz;
        }
            break;
        case LSAudioQuality_High:
        {
            audioConfig.audioBitrate = LSAudioBitrate_128Kbps;
            audioConfig.audioSampleRate = LSAudioSampleRate_44100Hz;
        }
            break;
        case LSAudioQuality_VeryHigh:
        {
            audioConfig.audioBitrate = LSAudioBitrate_128Kbps;
            audioConfig.audioSampleRate = LSAudioSampleRate_48000Hz;
        }
            break;
        default:
        {
            audioConfig.audioBitrate = LSAudioBitrate_96Kbps;
            audioConfig.audioSampleRate = LSAudioSampleRate_44100Hz;
        }
            break;
    }
    return audioConfig;
}

#pragma mark - setter
- (NSUInteger)bufferLength {
    return 1024 * 2 * self.numberOfChannels;
}

@end
