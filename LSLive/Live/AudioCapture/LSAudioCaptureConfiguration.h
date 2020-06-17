//
//  LSAudioCaptureConfiguration.h
//  LSLive
//
//  Created by demo on 2020/6/12.
//  Copyright © 2020 ls. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//音频码率
typedef NS_ENUM(NSUInteger, LSAudioBitrate) {
    LSAudioBitrate_32Kbps = 32000,
    LSAudioBitrate_64Kbps = 64000,
    LSAudioBitrate_96Kbps = 96000,
    LSAudioBitrate_128Kbps = 128000,
    LSAudioBitrate_Default = LSAudioBitrate_96Kbps
};

//音频采样率
typedef NS_ENUM(NSUInteger, LSAudioSampleRate) {
    LSAudioSampleRate_16000Hz = 16000,
    LSAudioSampleRate_44100Hz = 44100,
    LSAudioSampleRate_48000Hz = 48000,
    LSAudioSampleRate_Default = LSAudioSampleRate_44100Hz
};

//音频质量=音频码率+音频采样率
typedef NS_ENUM(NSUInteger, LSAudioQuality) {
    //低音频质量 audio sample rate:16KHz, audio bitrate
    LSAudioQuality_Low = 0,
    LSAudioQuality_Medium = 1,
    LSAudioQuality_High = 2,
    LSAudioQuality_VeryHigh = 3,
    LSAudioQuality_Default = LSAudioQuality_High
};

@interface LSAudioCaptureConfiguration : NSObject

+ (instancetype)defaultAudioConfiguration;

+ (instancetype)defaultAudioConfigurationForQuality:(LSAudioQuality)audioQuality;

//声道数
@property (nonatomic, assign) NSUInteger numberOfChannels;

//音频码率
@property (nonatomic, assign) LSAudioBitrate audioBitrate;

//音频采样率
@property (nonatomic, assign) LSAudioSampleRate audioSampleRate;

//缓冲区大小
@property (nonatomic, assign) NSUInteger bufferLength;
@end

NS_ASSUME_NONNULL_END
