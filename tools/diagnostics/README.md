# 显示与 HEVC 诊断

这些工具只查询显示状态或创建独立解码会话，不修改 EFI、EDID、启动参数或亮度，也不会重启。需要 macOS Command Line Tools。显示查询应在用户已经登录且桌面就绪时运行；开机早期的空结果不能直接当作显示失败。

## HDR / EDR

```text
clang -fobjc-arc -O1 -Wno-deprecated-declarations probe-display.m -o probe-display -framework AppKit -framework CoreGraphics -framework VideoToolbox
./probe-display
```

重点看 `potentialEDR`、`currentEDR` 与当前像素编码。`potentialEDR > 1` 才表明当前系统向应用提供 EDR 能力；值为 1 不能证明面板硬件不支持 HDR。CGDisplayMode 的像素编码是当前模式信息，不是全部底层色深能力。

当前 16Z90RS 的原厂 256 字节 EDID 包含 DisplayID 2.0、10 bpc、PQ、BT.2020 RGB 和 HDR 静态元数据。恢复完整 EDID 后显示正常，但 HDR 仍未开放。不要用虚构的 HDR 开关或猜测的峰值亮度替代原厂声明。

## 强制 HEVC 硬件解码

```text
clang -fobjc-arc -O1 -Wno-deprecated-declarations verify-hevc.m -o verify-hevc -framework Foundation -framework AVFoundation -framework VideoToolbox -framework CoreVideo -framework CoreMedia
./verify-hevc sample-main.mp4 8 hardware
./verify-hevc sample-main10.mp4 10 hardware
```

先保存工作，使用短样片。本机某些播放器/直播路径仍可能触发 GPU 挂死；本工具不是破坏性压力测试，也不能保证驱动挂起时仍可及时退出。

`hardware` 会设置 `RequireHardwareAcceleratedVideoDecoder=true`，不接受静默软解回退。有效成功结果应同时满足：

- `createStatus=0`；
- `usingHardwareBefore=true` 且 `usingHardwareAfter=true`；
- `submittedSamples=decodedFrames`，且不为 0；
- `submitErrors=0`、`callbackErrors=0`，输出尺寸与样片一致。

零长度 AVAssetReader 标记单独计入 `emptyMarkers`，不会提交给解码器。`software` 可作为对照；软件解码器未必实现硬解状态属性，属性查询不受支持不能误报成硬解成功。

已验证：1280×720、24 fps、4 秒的 HEVC Main 与 Main10 各 96/96 帧，零解码错误；Main10 输出为 10-bit YCbCr。这个结果不覆盖所有 codec profile、直播封装、交错码流、色彩转换、HDR 显示或长时间稳定性。

可用本机已有 FFmpeg 生成不含个人数据的样片：

```text
ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=24 -t 4 -c:v libx265 -pix_fmt yuv420p -tag:v hvc1 -an sample-main.mp4
ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=24 -t 4 -c:v libx265 -pix_fmt yuv420p10le -tag:v hvc1 -an sample-main10.mp4
```

不要仅凭 `IOGVAHEVCDecode`、GVA 日志条数或瞬时 GPU 利用率判断是否真正硬解。WEX 的恢复调用计数应从 `TGLRecoveryLive` 的头两个 64-bit 值读取（calls/returns）；`Ready=Yes` 只证明钩子已安装，不保证故障恢复成功。
