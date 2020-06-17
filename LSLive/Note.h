//
//  Note.h
//  LSLive
//
//  Created by demo on 2020/6/11.
//  Copyright © 2020 ls. All rights reserved.
//

/**
 采集：
 视频采集：LSVideoCapture
 视频采集配置：LSVideoCaptureConfiguration
 
 音频采集：LSAudioCapture
 音频采集配置：LSAudioCaptureConfiguration
 
 数据处理(美颜) GPUImage
 暂无
 
 视频编码：LSVideoEncoder
 音频编码：LSAudioEncoder
 
 封包：编码后的视频数据和音频数据对齐后 封包
 暂无
 
 传输：
 tcp 涉及到粘包、拆包问题
 udp 涉及到传输字节限制问题 最大是65535，减去包头20字节，最多传输实际内容大小为65515字节
 
 
 视频解码：LSVideoDecoder
 音频解码：LSAudioDecoder
 
 
 
 
 
 
 */
