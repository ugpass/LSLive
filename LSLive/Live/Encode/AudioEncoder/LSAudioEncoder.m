//
//  LSAudioEncoder.m
//  LSLive
//
//  Created by demo on 2020/6/14.
//  Copyright © 2020 ls. All rights reserved.
//

#import "LSAudioEncoder.h"

@interface LSAudioEncoder()
{
    AudioConverterRef mAudioConverterRef;
    char *aacBufferCache;//aac数据缓冲区
    char *remainBuf;//采集到的数据 处理时存放 不够缓冲区长度的数据
    NSUInteger remainLength;
}

@property (nonatomic, strong) LSAudioCaptureConfiguration *configuration;

@end

@implementation LSAudioEncoder

- (instancetype)initWithConfiguration:(LSAudioCaptureConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;
        _writeToFile = NO;
        _audioEncodeQueue = dispatch_queue_create("ls_audio_encode_queue", DISPATCH_QUEUE_SERIAL);
        if (!aacBufferCache) {
            aacBufferCache = malloc(_configuration.bufferLength);
        }
        if (!remainBuf) {
            remainBuf = malloc(_configuration.bufferLength);
        }
    }
    return self;
}

- (void)startAudioEncoderWithAudioData:(NSData *)audioData {
    dispatch_sync(self.audioEncodeQueue, ^{
        if (![self initAudioEncoder]) {
            NSLog(@"startAudioEncoderSampleBuffer initAudioEncoder false");
            return;
        }
        //需要先计算 audioData 长度
         
        if (remainLength + audioData.length >= self.configuration.bufferLength) {
            //采集的数据 大于 缓冲区长度 需要截取
            //临时buf和本次audioData数据的总长度
            NSUInteger totalLength = remainLength + audioData.length;
            
            //总共有几个 需要可以送入编码器的 bufferLength
            NSUInteger needEncodeCount = totalLength / self.configuration.bufferLength;
            
            //开辟临时的 存放 临时buf 和 新一次的audioData数据
            char *totalBuf = malloc(totalLength);
            //初始指针 指向总数据的最开头位置
            char *p = totalBuf;
            
            //初始化totalBuf所有数据为0
            memset(totalBuf, 0, totalLength);
            //将之前剩余的数据放入总buf
            memcpy(totalBuf, remainBuf, remainLength);
            //将本次的audioData数据 放入总buf
            memcpy(totalBuf + remainLength, audioData.bytes, audioData.length);
            
            //遍历需要送入编码器的buffer个数
            for (int idx = 0; idx < needEncodeCount; idx ++) {
                [self encodeAudioBuffer:p];
                p += self.configuration.bufferLength;
            }
            
            //计算出剩余数据长度
            remainLength = totalLength % self.configuration.bufferLength;
            //将临时buf中数据清空
            memset(remainBuf, 0, self.configuration.bufferLength);
            //把剩余的数据 放入临时buf
            //totalBuf + (totalLength - remainLength) 从totalBuf的开始 往后移(totalLength - remainLength) 开始拷贝
            memcpy(remainBuf, totalBuf + (totalLength - remainLength), remainLength);
            
            
            //释放临时的总buf
            free(totalBuf);
            
        }else {
            //采集的数据长度 小于 缓冲区长度 需要累加
            //将audioData的数据 放入 临时buf存放，
            //由于临时buf之前可能存在数据，需要从remainLength处开始拷贝audioData的数据
            memcpy(remainBuf + remainLength, audioData.bytes, audioData.length);
            remainLength = remainLength + audioData.length;
        }
    });
}

- (void)stopAudioEncoder {
    if (fileHandele) {
        [fileHandele closeFile];
        fileHandele = NULL;
    }
}

- (void)dealloc {
    if (aacBufferCache) {
        free(aacBufferCache);
    }
    if (remainBuf) {
        free(remainBuf);
    }
    NSLog(@"%s", __func__);
}

#pragma mark - private
- (BOOL)initAudioEncoder {
    if (mAudioConverterRef) {
        return YES;
    }
    
    /**
     struct AudioStreamBasicDescription
     {
         Float64             mSampleRate;
         AudioFormatID       mFormatID;
         AudioFormatFlags    mFormatFlags;
         UInt32              mBytesPerPacket;
         UInt32              mFramesPerPacket;
         UInt32              mBytesPerFrame;
         UInt32              mChannelsPerFrame;
         UInt32              mBitsPerChannel;
         UInt32              mReserved;
     };
     */
    //输入格式
    AudioStreamBasicDescription inputFormat = {0};
    inputFormat.mSampleRate = _configuration.audioSampleRate;//采样率
    inputFormat.mFormatID = kAudioFormatLinearPCM;//输入数据格式为PCM
    inputFormat.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
    inputFormat.mChannelsPerFrame = (UInt32)_configuration.numberOfChannels;//每一帧的声道数
    inputFormat.mFramesPerPacket = 1;//每个包的帧数
    inputFormat.mBitsPerChannel = 16;//每个采样所占位数
    inputFormat.mBytesPerFrame = inputFormat.mBitsPerChannel / 8 * inputFormat.mChannelsPerFrame;//每一帧的字节
    inputFormat.mBytesPerPacket = inputFormat.mBytesPerFrame * inputFormat.mFramesPerPacket;//每一个包的字节
    
    //输出格式
    AudioStreamBasicDescription outputFormat;
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate = inputFormat.mSampleRate;//采样率和输入保持一致
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;//输出数据格式为AAC
    outputFormat.mChannelsPerFrame = (UInt32)_configuration.numberOfChannels;//每一帧的声道数
    outputFormat.mFramesPerPacket = 1024;
    
    const OSType subtype = kAudioFormatMPEG4AAC;
    AudioClassDescription inClassDesc[2] = {
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleSoftwareAudioCodecManufacturer
        },
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleHardwareAudioCodecManufacturer
        }
    };
    
    //初始化AudioConverterRef
    OSStatus status = AudioConverterNewSpecific(&inputFormat, &outputFormat, 2, inClassDesc, &mAudioConverterRef);
    if (status != noErr) {
        NSLog(@"AudioConverterNewSpecific error= %d", (int)status);
        return NO;
    }
    
    //设置编码码率
    UInt32 outputBitrate = (UInt32)_configuration.audioBitrate;
    UInt32 outputBitrateDataSize = sizeof(outputBitrate);
    status = AudioConverterSetProperty(mAudioConverterRef, kAudioConverterEncodeBitRate, outputBitrateDataSize, &outputBitrate);
    if (status != noErr) {
        NSLog(@"AudioConverterSetProperty error= %d", (int)status);
        return NO;
    }
    return YES;
}

- (void)encodeAudioBuffer:(char *)buffer {
    AudioBuffer inputBuf;
    inputBuf.mNumberChannels = 1;
    inputBuf.mData = buffer;
    inputBuf.mDataByteSize = (UInt32)self.configuration.bufferLength;
    
    //初始化缓冲列表
    AudioBufferList mBufferList;
    //在mBuffers数组中 AudioBuffer的数量
    mBufferList.mNumberBuffers = 1;
    mBufferList.mBuffers[0] = inputBuf;
    
    
    //初始化输出缓冲列表
    AudioBufferList ouputBufferList;
    ouputBufferList.mNumberBuffers = 1;
    ouputBufferList.mBuffers[0].mNumberChannels = inputBuf.mNumberChannels;
    ouputBufferList.mBuffers[0].mDataByteSize = inputBuf.mDataByteSize;
    ouputBufferList.mBuffers[0].mData = aacBufferCache;
    
    //ouputBufferList.mBuffers[0].mData和aacBufferCache 中的数据为编码后的数据
    //需要加上adts头 一般为7或9字节 比较多的是7字节
    //编码
    UInt32 outputDataPacketSize = 1;
    OSStatus status = AudioConverterFillComplexBuffer(mAudioConverterRef, inInputDataProc, &mBufferList, &outputDataPacketSize, &ouputBufferList, NULL);
    if (status != noErr) {
        NSLog(@"AudioConverterFillComplexBuffer error=%d", (int)status);
        return;
    }
    
    NSData *aacData = [NSData dataWithBytes:ouputBufferList.mBuffers[0].mData length:ouputBufferList.mBuffers[0].mDataByteSize];
    
    NSData *adtsData = [self adtsDataForPacketLength:aacData.length];
    
    NSMutableData *resultData = [[NSMutableData alloc] init];
    [resultData appendData:adtsData];
    [resultData appendData:aacData];
    
    if (self.writeToFile) {
        [fileHandele writeData:resultData];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(audioEncodeDidOutputData:)]) {
        [self.delegate audioEncodeDidOutputData:resultData];
    }
}

- (NSData *)adtsDataForPacketLength:(NSUInteger)packetLength {
    //https://cloud.tencent.com/developer/article/1608477
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;//AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;//44.1KHz
    int chanCfg = 1;//MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF;// 11111111 syncword
    packet[1] = (char)0xF9;// 11111001 syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    
    NSData *adtsData = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return adtsData;
}

#pragma mark - audioCallback
OSStatus inInputDataProc(AudioConverterRef inAudioConverter,
                         UInt32 *ioNumberDataPackets,
                         AudioBufferList *ioData,
                         AudioStreamPacketDescription * __nullable * __nullable outDataPacketDescription,
                         void * __nullable inUserData)
{
    //AudioConverterFillComplexBuffer 需要此函数 填充PCM数据
    AudioBufferList bufferList = *(AudioBufferList *)inUserData;
    ioData->mBuffers[0].mNumberChannels = 1;
    ioData->mBuffers[0].mData = bufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize = bufferList.mBuffers[0].mDataByteSize;
    return noErr;
}


#pragma mark - setter
- (void)setWriteToFile:(BOOL)writeToFile {
    if (_writeToFile != writeToFile) {
        _writeToFile = writeToFile;
        if (_writeToFile == YES) {
            filePath = [NSHomeDirectory() stringByAppendingPathComponent:@"/Documents/LSAudio.aac"];

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
