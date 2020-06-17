### 愿景

音视频采集

美颜 GPUImage

视频编码：以H264格式为主 VideoToolBox FFmpeg 硬编失败转软编，软编失败转硬编？

音频编码：AudioToolBox 或其他，AAC Opus等编码

传输：RTMP TCP私有协议 RTSP等

播放器：OpenGL ES/Metal，ijkplayer

更多：横竖屏切换，前后台切换，音视频同步，秒开，音频路由切换，回声抑制等


### 参考WebRTC以及[LFLiveKit](https://github.com/LaiFengiOS/LFLiveKit)

### 20200617

已实现的基本功能

 + 竖屏视频采集及预览
 + 基本AudioUnit音频采集
 + VideoToolBox 视频H264编码
 + AudioToolBox 音频AAC转码
 + 视频编码后写入文件，实时回调并解码显示，暂时为了效果使用UIImage显示
 + 音频编码后写入文件，使用VLC播放正常