//
//  LSAudioCapture.m
//  LSLive
//
//  Created by demo on 2020/6/12.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSAudioCapture.h"

@interface LSAudioCapture()

@property (nonatomic, strong, nullable) LSAudioCaptureConfiguration *audioConfiguration;

@property (nonatomic, assign) BOOL isRunning;

@property (nonatomic, strong) dispatch_queue_t audioCaptureQueue;

@property (nonatomic, assign) AudioUnit audioUnit;
@property (nonatomic, assign) AudioComponent inputComponent;

@end

@implementation LSAudioCapture

#pragma  mark - life cycle
- (instancetype)initWithAudioConfiguration:(LSAudioCaptureConfiguration *)audioConfiguration {
    if (self = [super init]) {
        _audioConfiguration = audioConfiguration;
        _isRunning = NO;
        _audioCaptureQueue = dispatch_queue_create("ls_audio_capture_queue", DISPATCH_QUEUE_SERIAL);
        [self addObservers];
        [self initAudioUnit];
    }
    return self;
}

- (void)startCaptureAudio {
    if (self.isRunning == YES) {
        NSLog(@"audio unit is running");
        return;
    }
    dispatch_async(self.audioCaptureQueue, ^{
        NSError *error = nil;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:&error];
        if (error) {
            NSLog(@"startCaptureAudio setCategory error: %@", error);
            return;
        }
        OSStatus status = AudioOutputUnitStart(self.audioUnit);
        if (status != noErr) {
            NSLog(@"startCaptureAudio AudioOutputUnitStart error: %d", (int)status);
            return;
        }
        self.isRunning = YES;
    });
}

- (void)stopCaptureAudio {
    if (self.isRunning == NO) {
        NSLog(@"audio unit is running");
        return;
    }
    dispatch_sync(self.audioCaptureQueue, ^{
        self.isRunning = NO;
        OSStatus status = AudioOutputUnitStop(self.audioUnit);
        if (status != noErr) {
            NSLog(@"stopCaptureAudio AudioOutputUnitStop error: %d", (int)status);
            return;
        }
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    dispatch_sync(self.audioCaptureQueue, ^{
        if (self.audioUnit) {
            self.isRunning = NO;
            AudioOutputUnitStop(self.audioUnit);
            AudioComponentInstanceDispose(self.audioUnit);
            self.audioUnit = nil;
            self.inputComponent = nil;
        }
    });
    NSLog(@"%s", __func__);
}

#pragma mark - private
- (void)initAudioUnit {
    //audio component desc
    AudioComponentDescription audioComponentDesc;
    audioComponentDesc.componentType = kAudioUnitType_Output;
    audioComponentDesc.componentSubType = kAudioUnitSubType_RemoteIO;//原声未处理的数据
//    audioComponentDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;//消除回声增强人声
    audioComponentDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioComponentDesc.componentFlags = 0;
    audioComponentDesc.componentFlagsMask = 0;
    
    self.inputComponent = AudioComponentFindNext(NULL, &audioComponentDesc);
    //audio unit
    OSStatus status = AudioComponentInstanceNew(self.inputComponent, &_audioUnit);
    if (status != noErr) {
        NSLog(@"initAudioUnit - create audioUnit error: %d", (int)status);
        return;
    }
    
    //set property
    UInt32 flagOne = 1;
    AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));
    
    //basic desc
    AudioStreamBasicDescription audioStreamBasicDesc = {0};
    audioStreamBasicDesc.mSampleRate = _audioConfiguration.audioSampleRate;
    audioStreamBasicDesc.mFormatID = kAudioFormatLinearPCM;
    audioStreamBasicDesc.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
    audioStreamBasicDesc.mChannelsPerFrame = (UInt32)_audioConfiguration.numberOfChannels;
    audioStreamBasicDesc.mFramesPerPacket = 1;
    audioStreamBasicDesc.mBitsPerChannel = 16;
    audioStreamBasicDesc.mBytesPerFrame = audioStreamBasicDesc.mBitsPerChannel / 8 * audioStreamBasicDesc.mChannelsPerFrame;
    audioStreamBasicDesc.mBytesPerPacket = audioStreamBasicDesc.mBytesPerFrame * audioStreamBasicDesc.mFramesPerPacket;
    
    //callback
    AURenderCallbackStruct callback;
    callback.inputProc = audioInputCallBack;
    callback.inputProcRefCon = (__bridge void*)self;
    
    AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioStreamBasicDesc, sizeof(audioStreamBasicDesc));
    AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &callback, sizeof(callback));
    
    status = AudioUnitInitialize(self.audioUnit);
    if (status != noErr) {
        NSLog(@"initAudioUnit - AudioUnitInitialize error: %d", (int)status);
        return;
    }
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setPreferredSampleRate:_audioConfiguration.audioSampleRate error:&error];
    if (error) {
        NSLog(@"initAudioUnit - setPreferredSampleRate error : %@", error);
        return;
    }
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:&error];
    if (error) {
        NSLog(@"initAudioUnit - setCategory error : %@", error);
        return;
    }
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (error) {
        NSLog(@"initAudioUnit - setActive error : %@", error);
        return;
    }
}

- (void)addObservers {
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleRouteChange:)
                                                 name: AVAudioSessionRouteChangeNotification
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleInterruption:)
                                                 name: AVAudioSessionInterruptionNotification
                                               object: nil];
}

//route changed
- (void)handleRouteChange:(NSNotification *)noti {
    
}

//interrupteion
- (void)handleInterruption:(NSNotification *)noti {
    
}

static OSStatus audioInputCallBack (
                          void *inRefCon,
                          AudioUnitRenderActionFlags *ioActionFlags,
                          const AudioTimeStamp *inTimeStamp,
                          UInt32 inBusNumber,
                          UInt32 inNumberFrames,
                          AudioBufferList *ioData)
{
    @autoreleasepool {
        LSAudioCapture *audioCapture = (__bridge LSAudioCapture *)inRefCon;
        
        AudioBuffer mAudioBuffer;
        mAudioBuffer.mData = NULL;
        mAudioBuffer.mDataByteSize = 0;
        mAudioBuffer.mNumberChannels = 1;
        
        AudioBufferList mAudioBufferList = {0};
        mAudioBufferList.mBuffers[0] = mAudioBuffer;
        mAudioBufferList.mNumberBuffers = 1;
        
        //将数据放进bufferList
        OSStatus status = AudioUnitRender(audioCapture.audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &mAudioBufferList);
        if (status != noErr) {
            NSLog(@"audioInputCallBack error = %d", (int)status);
            return status;
        }
        
        //PCM转AAC的转换器每次需要1024个采样点才能完成一次转换
        //可以在本回调中做累计数据处理，也可以在送入数据到编码器前进行数据累计处理
        NSData *audioData = [NSData dataWithBytes:mAudioBufferList.mBuffers[0].mData length:mAudioBufferList.mBuffers[0].mDataByteSize];
        
        if (audioCapture.delegate && [audioCapture.delegate respondsToSelector:@selector(captureOutput:audioData:)]) {
            [audioCapture.delegate captureOutput:audioCapture audioData:audioData];
        }
//        NSLog(@"audioInputCallBack success = %ld", audioData.length);
        return noErr;
    }
}

@end
