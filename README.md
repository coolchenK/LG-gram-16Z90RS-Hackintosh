# LG gram Style 16 (16Z90RS) 黑苹果 · macOS Sequoia 15.8.2 · OpenCore 1.0.8

> English summary at the end.

LG gram Style 16（16Z90RS，2023 款，i5-1340P / Iris Xe / 3200×2000 OLED）运行 macOS Sequoia 15.8.2 的完整 EFI、补丁源码和安装后工具。

核显加速、120 Hz OLED、亮度、扬声器、触控板、Wi-Fi、蓝牙都已可用；**整机睡眠和休眠不可用**（固件只支持现代待机），已配置为"合盖只关屏、系统不睡眠"。

**本仓库的 EFI 已去除个人信息**：`PlatformInfo > Generic` 里的序列号、MLB、SystemUUID、ROM 都是占位值，使用前必须生成自己的（见[第 4 步](#4-生成-smbios)）。

---

## 目录

- [机型配置](#机型配置)
- [硬件工作状态](#硬件工作状态)
- [安装步骤](#安装步骤)
- [EFI 说明](#efi-说明)
- [本仓库的修复补丁](#本仓库的修复补丁)
- [排障](#排障)
- [目录结构](#目录结构)
- [致谢与许可](#致谢与许可)
- [English summary](#english-summary)

---

## 机型配置

| 部件 | 型号 |
|---|---|
| 机型 | LG gram Style 16（16Z90RS），2023 |
| CPU | Intel Core i5-1340P（Raptor Lake-P，4P + 8E，16 线程） |
| 核显 | Intel Iris Xe（`8086:A7A0`，rev 04，80 EU） |
| 屏幕 | 16" OLED 3200×2000 120 Hz（Samsung ATNA60BX02，eDP，VESA DPCD AUX 背光） |
| 内存 | 16 GB LPDDR5-6400（板载） |
| 硬盘 | SK hynix PC801 512 GB NVMe（`1C5C:1959`） |
| 无线 | Intel AX211（Wi-Fi `8086:51F1`，蓝牙 `8087:0033`） |
| 声卡 | Realtek ALC298（`1854:0492`）+ 4 颗智能功放 |
| 触控板 | TOPS0102（`35CC:0103`），I2C HID，挂在 I2C0（`8086:51E8`） |
| 键盘 | PS/2 |

| 软件 | 版本 |
|---|---|
| macOS | Sequoia 15.8.2（24H232） |
| OpenCore | 1.0.8 RELEASE（GUI：OpenCanopy / GoldenGate） |
| SMBIOS | MacBookPro16,2 |
| SIP | `csr-active-config = 03080000`（0x803，WhateverXe Graphics 要求） |

## 硬件工作状态

| 硬件 | 状态 | 说明 |
|---|---|---|
| CPU 电源管理 | ✅ | 16 线程，XCPM；"关于本机"显示 i5-1340P（RestrictEvents） |
| 核显加速 | ✅ | Metal 2 / OpenGL，WhateverXe + 本仓库补丁 + WhateverXe Graphics 0.4.1 |
| 内屏 120 Hz HiDPI | ✅ | 3200×2000，24 位色，无色带 |
| 内屏亮度 | ✅ | DPCD AUX 背光（11 位）；Fn 亮度键可用 |
| HEVC Main / Main10 硬解 | ✅ | VideoToolbox 强制硬解测试：720p、24 fps，各 96/96 帧，零解码错误；不代表所有直播/转换路径稳定 |
| 内屏 HDR | ❌ | 面板原厂 EDID 声明 PQ/BT.2020，Windows 可开启；已恢复完整 EDID，但当前 macOS 未提供 HDR 模式，仍在排查 |
| 自动关屏 / 锁屏后点亮 | ✅ | 需要 `-nodisplaysleepDC6 -nopsr`，否则点亮后整机冻结（见[补丁说明](#3-关屏再点亮整机冻结)） |
| 合盖 | ✅ | 只关屏，系统继续运行（`pmset disablesleep 1`） |
| 整机睡眠（S3） | ❌ | 固件按现代待机（S0ix）设计，S3 唤醒会冷启动，已禁用 |
| 休眠（写入硬盘） | ❌ | 试过 HibernationFixup，镜像写不进去，已放弃（见[已知问题](#已知问题)） |
| 键盘 | ✅ | VoodooPS2；Fn 亮度键、声音键可用 |
| 触控板 | ✅ | 多指手势；轮询模式；本仓库补丁修复"开机后不响应" |
| 扬声器 | ✅ | 需安装 `lggram-audiod`（初始化 4 颗功放、打开 0x17 引脚） |
| 耳机孔 | ✅ | 正常 |
| 内置麦克风 | ❌ | Intel SST 数字麦克风（PCH DMIC），macOS 不支持 |
| Wi-Fi（2.4G/5G） | ✅ | AirportItlwm（Sequoia alpha）；偶尔开机不自动连接，`wifikick` 会自动重连 |
| Wi-Fi 7 MLO / 仅 WPA3 网络 | ❌ | AirportItlwm 不支持 WPA3 |
| 蓝牙 | ✅ | lshbluesky 分支 IntelBluetoothFirmware 2.5.3 + 本仓库补丁 |
| NVMe 硬盘 | ✅ | NVMeFix |
| 电池 | ✅ | ECEnabler + SMCBatteryManager |
| 自动亮度 / 环境光传感器 | ❔ | macOS 尚无可用的环境光数据路径 |
| 摄像头 | ✅ | |
| USB | ✅ | 没做 USB 端口映射，但实测可用 |
| HDMI / USB-C 视频输出 | ❔ | 未测试 |

## 安装步骤

### 1. BIOS

开机按 F2 进入 BIOS，关闭 **Secure Boot**。

### 2. Windows 端准备（保留 Windows 双系统）

1. **暂停 BitLocker**（控制面板 → BitLocker → 暂停保护），否则改动分区或启动项后 Windows 会要求输入恢复密钥。
2. 在"磁盘管理"里压缩 C 盘，给 macOS 留出空间（建议 200 GB 以上），新建一个分区，安装时再用"磁盘工具"抹成 APFS。
3. 准备安装介质，二选一：
   - **U 盘**：用 OpenCore 自带的 `Utilities/macrecovery/macrecovery.py` 下载 Sequoia 恢复镜像，放到 FAT32 U 盘的 `com.apple.recovery.boot` 目录，再把本仓库的 `EFI` 文件夹复制到 U 盘根目录；
   - **硬盘分区**：再分一个 2 GB 的 FAT32 分区放 `com.apple.recovery.boot`；也可以另建一个 exFAT 分区放离线安装包 `InstallAssistant.pkg`。

### 3. 把 EFI 放进 EFI 分区

以管理员身份打开命令提示符：

```bat
mountvol S: /S
xcopy /E /I EFI\OC S:\EFI\OC
```

- **不要**覆盖 `S:\EFI\Boot` 和 `S:\EFI\Microsoft`（Windows 的引导文件）。本仓库的 `EFI/BOOT/BOOTx64.efi` 只给 U 盘启动用。
- 添加 OpenCore 的固件启动项，并排到第一位：

```bat
bcdedit /copy {bootmgr} /d "OpenCore"
rem 记下上一条命令输出的 {GUID}，替换到下面两条里
bcdedit /set {GUID} path \EFI\OC\OpenCore.efi
bcdedit /set {fwbootmgr} displayorder {GUID} /addfirst
mountvol S: /D
```

### 4. 生成 SMBIOS

用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成 **MacBookPro16,2** 的序列号，填进 `EFI/OC/config.plist` 的 `PlatformInfo > Generic`：

| 键 | 填什么 |
|---|---|
| `SystemSerialNumber` | 生成的序列号 |
| `MLB` | 生成的主板序列号 |
| `SystemUUID` | 生成的 UUID |
| `ROM` | 网卡 MAC 地址（6 字节） |

可以在 [Apple 保修查询](https://checkcoverage.apple.com) 里确认序列号"无法验证"，避免和真机冲突。

### 5. 安装 macOS

重启，在 OpenCore 菜单里选恢复或安装器，用"磁盘工具"把第 2 步留出的分区抹成 APFS，然后安装 Sequoia。安装阶段内屏没有加速是正常的。

### 6. 安装后

1. **核显加速**：安装 [WhateverXe Graphics 0.4.1](https://github.com/b00t0x/WhateverXe-Graphics/releases) 的 pkg，重启。EFI 里已经带了它要求的 AMFIPass 1.4.1 Mod 和 SIP 设置。
2. **辅助工具**（需要 Xcode Command Line Tools，`xcode-select --install`）：

   ```bash
   sudo ./tools/install.sh
   ```

   会安装三个工具：
   - `lggram-audiod`：扬声器后台服务；
   - `wifikick`：开机 60 秒内没拿到 IP，就自动重开一次 Wi-Fi；
   - `vi2ckick`：触控板诊断和手动修复。

3. **关闭睡眠**（S3 和休眠都用不了，不关的话合盖或闲置就会冷启动）：

   ```bash
   sudo pmset -a sleep 0 hibernatemode 0 standby 0 autopoweroff 0 powernap 0 proximitywake 0
   sudo pmset -a disablesleep 1
   sudo rm -f /var/vm/sleepimage
   ```

4. **默认启动 macOS**：系统设置 → 通用 → 启动磁盘，选 macOS。

### 7. 隐藏 OpenCore 菜单里多余的条目（可选）

OpenCore 会把固件启动项和扫描到的引导文件都列出来，这台机器上会出现两个 Windows 和一个 "SYSTEM"。在对应目录放一个 `.contentVisibility` 文件即可隐藏（文件内容不要带换行）：

| 文件 | 内容 | 隐藏的是 |
|---|---|---|
| `EFI/OC/.contentVisibility`（本仓库已带） | `Disabled` | "SYSTEM"：bcdedit 建的 OpenCore 启动项把 OpenCore 自己也列了出来 |
| EFI 分区 `EFI/Boot/.contentVisibility` | `Disabled` | EFI 分区里 Windows 的备用引导文件 |
| LG 恢复分区（卷标 `LGEFI`）`EFI/Boot/.contentVisibility` | `Auxiliary` | LG 一键恢复；改成辅助项，菜单里按空格才显示 |

macOS 下挂载 LG 恢复分区：`sudo mount -t msdos /dev/disk0s9 /tmp/lgefi`（分区号以 `diskutil list` 为准）。

## EFI 说明

### 启动参数

| 参数 | 作用 |
|---|---|
| `-allow3d -disablegfxfirmware` | WhateverXe 必需 |
| `-igfxdvmt` | 配合 `framebuffer-stolenmem`，修正 BIOS 固定的 60 MB DVMT |
| `-wex-auxbl` | 本仓库 WEX 补丁：接管 VESA DPCD AUX 背光的 eDP 内屏 |
| `-nodisplaysleepDC6 -nopsr` | 苹果 TGL 显卡驱动自带开关：关屏时不进 DC6、关闭面板自刷新，修复关屏再点亮后整机冻结 |
| `revcpu=1` | RestrictEvents：显示真实 CPU 名称（配合 NVRAM `revcpuname`） |
| `alcverbs=1` | AppleALC：开放 verb 接口，`lggram-audiod` 需要 |
| `-btlfxallowanyaddr` | BlueToolFixup：允许任意蓝牙地址 |
| `-vi2c-force-polling` | VoodooI2C：触控板用轮询模式（GPIO 中断模式不稳定） |

### 驱动

| Kext | 版本 | 来源 | 说明 |
|---|---|---|---|
| Lilu | 1.7.2 | acidanthera | |
| VirtualSMC / SMCBatteryManager / SMCProcessor | 1.3.8 | acidanthera | |
| WhateverXe | 0.8.0 + 本地补丁 | [b00t0x/WhateverXe](https://github.com/b00t0x/WhateverXe) | 用 `patches/WhateverXe-0.8.0-lg-gram-rplp-edp.patch` 自行编译 |
| AMFIPass | 1.4.1 Mod | [WhateverXe-Graphics extras](https://github.com/b00t0x/WhateverXe-Graphics) | WhateverXe Graphics 要求，不能换成上游版 |
| AppleALC | 1.9.8 | acidanthera | layout-id 3 |
| RestrictEvents | 1.1.6 | acidanthera | CPU 名称 |
| ECEnabler | 1.0.6 | 1Revenger1 | 电池信息 |
| NVMeFix | 1.1.3 | acidanthera | |
| VoodooPS2Controller | 2.3.7 | acidanthera | 只启用键盘 |
| VoodooI2C | 2.9.1（CI，提交 `6be653a`） | [VoodooI2C](https://github.com/VoodooI2C/VoodooI2C) | 正式版 2.9.1 不认 Raptor Lake 的 I2C 控制器 `51E8` |
| VoodooI2CHID | 同上 + 本地补丁 | 同上 | `patches/VoodooI2CHID-lg-gram-ptp-fix.patch` |
| AirportItlwm | 2.4.0 alpha（`AirportItlwm-Sequoia-v2.4.0-RELEASE-alpha-7204c69`） | OpenIntelWireless itlwm 的 Sequoia 构建 | |
| IntelBluetoothFirmware | 2.5.3 | [lshbluesky/IntelBluetoothFirmware](https://github.com/lshbluesky/IntelBluetoothFirmware) | 上游 2.4.0 在 Sequoia 上 HCI 初始化失败 |
| IntelBTPatcher | 2.5.3 + 本地补丁 | 同上 | `patches/IntelBTPatcher-2.5.3-intel-only-filter.patch` |
| BlueToolFixup | 2.7.2 | acidanthera/BrcmPatchRAM | |
| BrightnessKeys | 1.0.3 | acidanthera | |

### ACPI

| 文件 | 作用 |
|---|---|
| `SSDT-PLUG-ALT` | CPU 以 `Device` 声明时的 XCPM 兼容表（Dortania） |
| `SSDT-EC-USBX-RTC` | 假 EC 设备（真 EC 名为 LGEC）、USBX 供电属性，并启用传统 RTC（关掉 AWAC） |
| `SSDT-XOSI` + 补丁 `_OSI → XOSI` | 让 DSDT 认为系统是 Windows 2015+，触控板 `TPD0._CRS` 才会提供 I2C 资源 |
| `SSDT-I2C0-PS3` + 补丁 `_PS3 → XPS3` | 原 `_PS3` 会把 I2C0 放进 D3 并清零 BAR0，`_PS0` 却是空的，导致触控板时好时坏 |
| `SSDT-PNLF` | 背光设备，给 AppleBacklight 用 |
| `SSDT-BRTN` + 补丁 `BRTN → XBTN` | Fn 亮度键：原 `BRTN` 的 DIDX 检查在这台机器上不成立，改为直接通知 `DD1F` |

源码在 `ACPI-src/`，编译后的 `.aml` 在 `EFI/OC/ACPI/`。

### 其他关键配置

- **CPU 伪装**：`Kernel > Emulate`，`Cpuid1Data = 55060A00 00008000 …`，`Cpuid1Mask = FFFFFFFF 0000FF00 …`；`ProvideCurrentCpuInfo = true`。大小核混合的 i5-1340P 不这样设置，会卡在 `EXITBS:START`。
- **处理器类型**：`ProcessorType = 0x0F01`，8 核以上 RestrictEvents 才会显示自定义 CPU 名。
- **核显**：`framebuffer-patch-enable`、`framebuffer-stolenmem = 0000C003`；`AAPL00,override-no-connect` 使用通过 DDC 读取并校验的原厂完整 EDID（256 字节），保留 DisplayID 2.0 中的 PQ、BT.2020 和 HDR 静态元数据。此前 128 字节覆盖值隐藏了扩展块。恢复元数据后显示与 HEVC 硬解正常，但 macOS HDR 模式仍未开放。
- **声卡**：`layout-id = 3`。
- **蓝牙**：NVRAM 里的 `bluetoothExternalDongleFailed = 00` 和 `bluetoothInternalControllerInfo` 全 0，同时写在 `Add` 和 `Delete` 里。

## 本仓库的修复补丁

### 1. WhateverXe：Raptor Lake-P eDP 内屏（`patches/WhateverXe-*.patch`）

上游 WEX 0.8.0 的 Raptor Lake-P eDP 路径作者还没在真机上测过。在这台机器上要改的地方：

1. **背光类型**：`nativePPS0()` 只接受 PWM 背光的内屏。这块 OLED 在 VBT 里登记的是 VESA AUX（类型 5），面板因此没被接管。加 `-wex-auxbl` 后允许接管。
2. **开机交接**：eDP 开机交接前要先对面板端口执行 `setPortMode(1)`。
3. **像素时钟**：苹果驱动的 `adjustPixelClock` 在这条路径上返回的是指针，导致行时间为 0、黑屏。改成从 `PIPE_WM_LINETIME` 寄存器和 LINK_M/N 推算。
4. **时钟预算**：`Display13WM::clockFits` 按每时钟 2 像素计算预算（120 Hz 需要约 809.5 MHz 像素时钟，CDCLK 只有 652.8 MHz）。
5. **刷新率保护**：`SetupTimings` 在苹果驱动里拿到的是未初始化的时序，会除以 0，加了兜底。
6. **时序补全**：`setupDisplayTiming` 在 AGDC 回调失败时不写输出，补成先复制输入、再用实际寄存器的值覆盖。顺带修好了色带问题。
7. **背光写入**：通过 `AppleIntelPort::writeAUX` 写 DPCD `0x722/0x723`。

编译方法：`git clone https://github.com/b00t0x/WhateverXe` → `git checkout 0.8.0`（`db438fdf4d5fe903f5dfbc65537ed3884e2ea980`）→ `git apply patches/WhateverXe-0.8.0-lg-gram-rplp-edp.patch` → 按上游文档准备 MacKernelSDK 与 Lilu 1.7.2 开发头文件 → `python3 tools/build.py --release`。请将补丁路径替换为本仓库中的实际位置。配套安装 WhateverXe Graphics 0.4.1。

运行上游 CPU 测试前，再应用 `patches/WhateverXe-0.8.0-lg-tests.patch`（只适配测试夹具，不改运行时代码），然后执行 `python3 tools/test.py`。当前 0.8.0 + LG 补丁组合在 macOS 上通过 **208/208** 项检查，覆盖新增 AUX 背光和时序回退逻辑。实机 HEVC/HDR 查询方法见 [诊断工具说明](tools/diagnostics/README.md)。

### 2. 触控板开机后不响应（`patches/VoodooI2CHID-*.patch`）

VoodooI2C 把触控板切到精确触控板模式后，这块 TOPS0102 还需要打开 **Selective Reporting（报告 5：触摸面开关 + 按键开关）** 才会上报触摸数据，VoodooI2C 从来不写这一项。补丁做了这几件事：

- 开机后第 3、10、30 秒，每次输入模式被改写后的 0.5 秒，以及唤醒后，都写入 `05 03 00` 和 `03 03 00`。报告 3 和 5 各带 **2 字节**数据，VoodooI2C 的 `setReport` 会去掉开头的报告编号，所以必须传"编号 + 2 字节"，只传 1 字节会被触控板忽略。
- 增加 `VoodooI2CKick`、`VoodooI2CSetFeature`、`VoodooI2CGetFeature`、`VoodooI2CDiag` 四个注册表属性接口，配合 `tools/touchpad/vi2ckick.c` 使用。

编译：`tools/touchpad/build-voodooi2chid.sh`（只需要 Command Line Tools，不用 Xcode 工程），把生成的二进制替换进 CI 版 kext。

### 3. 关屏再点亮整机冻结

**现象**：屏幕自动关闭后再点亮，几秒到几十秒内整机冻结，网络也断开。如果系统先进入"暗唤醒"再睡眠，就会 panic：`Sleep transition timed out ... IOGraphicsFamily`。

**原因**：苹果的 Tiger Lake 显卡驱动在显示器休眠（doze）时会让显示引擎进入 DC6，并上传驱动自带的 **Tiger Lake** 显示微控制器程序，这个程序不适用于 Raptor Lake-P。点亮后显示引擎不停地发中断（中断风暴）。我用自制的寄存器跟踪器加看门狗抓到过一次 panic，中断寄存器被访问约 42.5 万次/秒，正常约 1000 次/秒。

**修复**：使用苹果驱动自带的启动参数 `-nodisplaysleepDC6 -nopsr`。关屏 30 秒、60 秒、120 秒的长时间测试都通过了。

驱动里还有 `-noDC9`、`-nopsrexit`、`-forcepsr` 这几个开关，这台机器暂时用不上。

### 4. 蓝牙登录时内核崩溃（`patches/IntelBTPatcher-*.patch`）

IntelBTPatcher 会挂钩所有 USB 设备的 `deviceRequest`。登录时摄像头服务 UVCAssistant 发来的请求，描述符没有固定在内存里，被它读取就会 panic。补丁限制它只处理 Intel 蓝牙控制器（`idVendor 0x8087`、`bDeviceClass 0xE0`）。

### 5. 扬声器（`tools/audio/`）

ALC298 后面接了 4 颗智能功放（`0x38/0x39/0x3c/0x3d`），需要按 Linux `ALC298_FIXUP_LG_GRAM_STYLE_14` 的系数序列初始化，播放时才打开。AppleALC 的 layout 3 只驱动 `0x14` 引脚，第二个扬声器引脚 `0x17` 也要打开。`lggram-audiod` 通过 AppleALC 的 `ALCUserClientProvider`（需要 `alcverbs=1`）做这些事，唤醒后会重新初始化。

## 排障

| 情况 | 办法 |
|---|---|
| 显卡驱动导致开不了机 | 启动参数临时加 `-wexoff`（关闭 WEX）或 `-wex-noaccel`（只要帧缓冲、不要加速） |
| macOS 起不来，需要改 EFI | 进 Windows，管理员命令提示符执行 `mountvol S: /S`，修改 `S:\EFI\OC` |
| 触控板没反应 | `vi2ckick diag` 看计数；手动修复：`vi2ckick set 050300; vi2ckick set 030300` |
| 开机后 Wi-Fi 不自动连 | `wifikick` 会自动处理，日志在 `/var/log/wifikick.log` |
| 没声音 | `sudo launchctl kickstart -k system/com.lggram.audiod`，日志在 `/var/log/lggram-audiod.log` |
| 重置 NVRAM 后默认进了 Windows | 系统设置 → 启动磁盘，重新选 macOS |

### 已知问题

- **图形/视频稳定性**：0.8.0 在本机 Sequoia 上已启用挂死恢复钩子，但不保证所有故障都能恢复。HEVC Main/Main10 的强制硬解短样片测试通过；IPTV 播放仍出现过 GPU 挂起和 WindowServer watchdog 五国。不能由“支持硬解”推导所有播放器稳定。
- **HDR**：完整原厂 EDID 已恢复，面板声明 HDR10/PQ；当前 macOS 的 HDR 模式支持与 EDR 余量仍未开放。此项尚未修复。

- **整机睡眠（S3）**：FADT 里开着 `LOW_POWER_S0_IDLE_CAPABLE`，DSDT 的 `_S3` 只有在 `If (SS3)` 时才定义。macOS 进 S3 后唤醒会卡在固件阶段（`Sleep Wake failure in EFI 0x22 0x1f`），然后冷启动。
- **休眠**：
  - macOS 的睡眠策略（`X86PlatformPlugin`）会把 `hibernatemode 25` 否决成 `DeepIdle`（类型 7）。
  - 加 HibernationFixup（`hbfx-ahbm=1`、`hibernatemode 3`、`standbydelay` 设为 0）后，睡眠策略能改成休眠，但镜像仍写不进去，原因还没查清，所以没有放进 EFI。
  - 另外，这台机器运行时写入的 NVRAM 只在正常关机时才同步到闪存，强制断电会全部丢失。
- **触控板**用的是轮询模式。GPIO 中断模式下，开机初始化有时要 40 秒，偶尔失败。

## 目录结构

```
EFI/BOOT/BOOTx64.efi        OpenCore 引导文件（仅 U 盘启动用）
EFI/OC/                     OpenCore 1.0.8 + 驱动 + ACPI + OpenCanopy 主题
ACPI-src/                   SSDT 源码
patches/                    WhateverXe / VoodooI2CHID / IntelBTPatcher 补丁
tools/install.sh            安装后工具一键安装
tools/audio/                扬声器服务（lggram-audiod）和手动功放脚本
tools/wifikick/             开机 Wi-Fi 自动重连
tools/touchpad/             vi2ckick 和 VoodooI2CHID 编译脚本
```

## 致谢与许可

- [acidanthera](https://github.com/acidanthera)：OpenCore、Lilu、VirtualSMC、AppleALC、RestrictEvents、NVMeFix、VoodooPS2、BrcmPatchRAM、BrightnessKeys、HibernationFixup
- [b00t0x/WhateverXe](https://github.com/b00t0x/WhateverXe) 与 [WhateverXe-Graphics](https://github.com/b00t0x/WhateverXe-Graphics)
- [samranahmad09/WhateverXe-RaptorLakeP](https://github.com/samranahmad09/WhateverXe-RaptorLakeP)：Raptor Lake-P 硬件调研
- [VoodooI2C](https://github.com/VoodooI2C/VoodooI2C)
- [OpenIntelWireless](https://github.com/OpenIntelWireless) 与 [lshbluesky/IntelBluetoothFirmware](https://github.com/lshbluesky/IntelBluetoothFirmware)
- [1Revenger1/ECEnabler](https://github.com/1Revenger1/ECEnabler)、dhinakg（AMFIPass）
- Linux 内核 `sound/hda/codecs/realtek` 的 LG gram Style 功放初始化序列

EFI 里的二进制和补丁过的组件，版权都归原作者，按各自的许可证分发：OpenCore、Lilu 等为 BSD-3-Clause，VoodooI2C、itlwm 等为 GPL-2.0。`patches/` 下的补丁遵循被修改项目的许可证。`tools/` 下的自写脚本以 MIT 许可发布。

本项目仅供学习研究。请遵守 Apple 的软件许可协议。

---

## English summary

OpenCore 1.0.8 EFI for the **LG gram Style 16 (16Z90RS, i5-1340P, Iris Xe A7A0, 3200×2000 120 Hz OLED)** running **macOS Sequoia 15.8.2**, SMBIOS MacBookPro16,2. SMBIOS identifiers in `config.plist` are placeholders: generate your own.

**Working**:
- Iris Xe acceleration (WhateverXe 0.8.0 + the eDP/DPCD-backlight patch in `patches/`, plus WhateverXe Graphics 0.4.1), 120 Hz HiDPI and brightness, including Fn keys
- Display off/on, which needs the Apple TGL framebuffer boot-args `-nodisplaysleepDC6 -nopsr`; without them waking the display ends in a display-interrupt storm and a hard freeze
- I2C touchpad (VoodooI2C CI + a VoodooI2CHID patch that writes the PTP Selective Reporting feature with its full 2-byte payload)
- Speakers (`tools/audio` initialises the 4 smart amps), Wi-Fi (AirportItlwm), Bluetooth (lshbluesky IntelBluetoothFirmware 2.5.3 + an Intel-only IntelBTPatcher filter), NVMe and battery
- Camera and USB
- Hardware HEVC Main/Main10 decoding: forced-hardware VideoToolbox tests decoded 96/96 frames for each 720p24 sample, with zero decode errors. This is not a long-duration or all-player stability guarantee.
- The full 256-byte factory EDID is retained, including the original DisplayID 2.0 timings and HDR metadata; no HDR capabilities are invented.

**Not working / unresolved**:
- HDR output is not enabled in macOS despite the panel's native PQ/BT.2020 declaration and working HDR in Windows.
- IPTV playback can still hang the GPU and lead to a WindowServer watchdog panic, even with the 0.8.0 recovery hook active.
- S3 sleep: the firmware is Modern-Standby only, so resume becomes a cold boot
- Hibernation: the image is never written, even with HibernationFixup
- Internal DMIC, LG WMI Fn keys other than brightness, Wi-Fi 7 MLO / WPA3-only networks

**Untested**: external displays.

Install the EFI next to Windows' boot files in the ESP, add a firmware entry with `bcdedit`, install WhateverXe Graphics, run `sudo tools/install.sh`, and disable sleep with `pmset` (see step 6).
