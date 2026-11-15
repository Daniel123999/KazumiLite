# Kazumi Lite

iPhone 4S / iOS 9.3.6 / armv7 的番剧采集与在线观看客户端。参考 [Predidit/Kazumi](https://github.com/Predidit/Kazumi) 的功能与规则格式，使用 **Objective-C + UIKit + Theos** 重写，参考本机 YueduLite / D9Music 的 iOS 9 工程实践。

## 功能

- **Bangumi**：每日放送、热门、搜索、番剧详情、剧集列表、评论、排名与标签
- **自定义规则**：兼容 Kazumi 的 XPath / API（JSONPath-lite）规则；导入、编辑、导出、规则商店与镜像
- **播放**：AVPlayer 原生硬解，HLS / MP4，倍速、进度记忆、自动连播、选集、横屏、截图
- **弹幕**：弹弹Play（可配置凭据）/ BiliBili / 本地缓存；滚动、顶部、底部、字号、透明度、区域、描边、屏蔽词、时间偏移
- **追番与历史**：本地追番状态、观看进度、继续观看、Bangumi Token 同步
- **WebDAV**：历史、追番、规则、弹幕偏好备份 / 恢复 / 双向合并
- **离线下载**：HLS 分片下载、AES-128 解密、本地播放列表、MP4 直下
- **应用内更新**：Gitee / GitHub `update.json`，下载 IPA 后调用 `ipainstaller` / MobileInstallation 安装

## 安装

未签名 IPA，需要：

1. 已越狱的 iOS 9 设备（iPhone 4S 等 armv7 机型）
2. AppSync Unified
3. 用 Filza / ipainstaller / SSH 安装 `KazumiLite.ipa`

首次启动后到「我的 → 规则管理」确认内置规则，或到「规则商店」更新。内置规则可能随时失效，规则本身由第三方站点维护。

## 构建

需要 Theos + `iPhoneOS9.3.sdk`：

```bash
cd ios
make clean
make TARGET=iphone:clang:9.3:9.0 ARCHS=armv7 FINALPACKAGE=1
APP_NAME=KazumiLite OUTPUT_IPA_NAME=KazumiLite.ipa ./make_ipa.sh
```

CI：`.github/workflows/build-ios.yml`（ubuntu-latest + Theos + 预编译 iOS 工具链 + iPhoneOS9.3.sdk 补丁）。

## iOS 9 限制

- **Anime4K 实时超分**：A5 GPU 与 AVPlayer 管线无法承载多 pass 着色器，本版本不提供（不伪装为已实现）。
- **一起看（SyncPlay）/ DLNA 投屏**：协议与服务端依赖较重，本版本未实现。
- **部分视频源**：新版 WebKit / DRM / 验证码源在 iPhone 4S 上可能无法解析，可切换到「网页播放」或换源。
- **HTTPS**：iOS 9 根证书库较旧，网络层对失败证书采用放行策略（与 YueduLite 一致），仅在越狱自用场景使用。

## 免责声明

本项目不提供、不存储任何视频内容。视频来自第三方规则站点，弹幕来自弹弹Play / BiliBili 公开接口，番剧元数据来自 Bangumi。请遵守所在地法律法规，支持正版；缓存数据应在 24 小时内清除。

规则格式与部分解析思路来自 Kazumi（GPL-3.0）。本项目以 GPL-3.0 发布。
