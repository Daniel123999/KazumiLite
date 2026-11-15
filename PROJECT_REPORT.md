# Kazumi Lite 项目报告（iOS 9 / iPhone 4S）

> 目标设备：iPhone 4S（iOS 9.3.6，armv7，512 MB RAM，320×480 pt）  
> 构建：Theos + iPhoneOS9.3 SDK + `TARGET=iphone:clang:9.3:9.0` + `ARCHS=armv7`  
> 参考实现：`C:\Users\25744\AppData\Local\Temp\opencode\work`（YueduLite）、`C:\Users\25744\Documents\refs\D9Music`（D9Music）  
> 上游：Predidit/Kazumi（Flutter/Dart，GPL-3.0）

## 1. 上游项目分析

### 1.1 技术栈

| 层 | Kazumi |
|---|---|
| UI | Flutter / Dart，Material 3，mobx |
| 播放 | media_kit（libmpv），Anime4K 着色器 |
| 规则 | XPath（`xpath_selector`）或 API 模式（JSONPath） |
| 番剧元数据 | Bangumi `api.bgm.tv` + `next.bgm.tv` |
| 弹幕 | 弹弹Play API（构建期注入 AppId/Secret） |
| 同步 | WebDAV（Hive 数据库文件）、Bangumi OAuth/Token |
| 平台 | Android 10+、iOS 13+、Windows 10+、macOS 10.15+、Linux |
| 体积 | 完整 Flutter + libmpv，依赖大量现代 API |

**直接移植不可行**：Flutter 引擎、libmpv、SwiftUI/SceneDelegate、iOS 13 最低版本和 arm64 依赖都不满足 iOS 9 / armv7。因此采用“功能重写 + 协议/规则兼容”的方案。

### 1.2 功能清单（README + lib 目录核对）

- 规则编辑器、番剧目录、搜索、时间表、字幕/弹幕、分集播放、多视频源、规则分享
- 硬件加速、高刷适配、追番列表、在线更新、历史记录、倍速、配色
- 跨设备同步、DLNA 投屏、外部播放器、Anime4K 超分、一起看（SyncPlay）、下载
- 图片识番（trace.moe）、Bangumi 账号同步、WebDAV、代理/镜像、低内存模式

### 1.3 关键协议/格式

- **规则**：JSON；`baseURL/searchURL/searchList/searchName/searchResult/chapterRoads/chapterResult`；`usePost`、`useWebview`、`useNativePlayer`、`useLegacyParser`；`searchMode/chapterMode` 为 `xpath|api`；API 模式含 `request`、`listPath/namePath/sourcePath`、`roadsPath/...`、`episodePage`。
- **Bangumi**：`/p1/calendar`、`/p1/trending/subjects`、`/v0/search/subjects`、`/p1/subjects/{id}`、`/v0/episodes`、`/p1/subjects/{id}/comments`、`/v0/users/-/collections/{id}`。
- **弹幕**：弹弹Play `p="time,mode,color,user"`；签名 `base64(sha256(appId + timestamp + path + secret))`；B 站 XML `<d p="...">`。
- **视频解析**：WebView 注入脚本，拦截 `m3u8` / `video.src` / XHR / fetch / iframe。

## 2. iOS 9 可行性矩阵

| Kazumi 功能 | iOS 9 方案 | 状态 |
|---|---|---|
| 番剧目录/搜索/时间表 | Bangumi API + UICollectionView | 已实现 |
| 详情/剧集/评论/关联 | Bangumi API + UITableView | 已实现（关联未展示） |
| 自定义 XPath 规则 | libxml2 HTML + XPath | 已实现 |
| API 规则 | JSONPath-lite 解析器 | 已实现（常用路径） |
| 规则编辑/导入/导出/商店 | 原生表单 + JSON 编辑器 + 镜像下载 | 已实现 |
| 多视频源 | 规则逐条搜索、手动链接兜底 | 已实现 |
| 在线播放 | AVPlayer（H.264 硬解） | 已实现 |
| 网页播放兜底 | WKWebView（iOS 8+） | 已实现 |
| 弹幕 | 自绘 CALayer/CoreText 覆盖层 + 弹弹/B 站 | 已实现（B 站依赖公开接口） |
| 追番/历史 | 本地 JSON + Bangumi Token 同步 | 已实现 |
| 倍速/连播/截图/横屏 | AVPlayer + AVPlayerItemVideoOutput | 已实现 |
| WebDAV 同步 | NSURLSession + PROPFIND/MKCOL/PUT/GET | 已实现（JSON 合并） |
| 下载 | HLS 分片 + AES-128 解密 + 本地 m3u8 | 已实现（顺序下载） |
| 应用内更新 | update.json + ipainstaller/MobileInstallation | 已实现 |
| 图片识番 | trace.moe multipart 上传 + Bangumi 匹配 | 已实现 |
| Anime4K 超分 | A5/AVPlayer 无法承载多 pass 着色器 | 明确不支持 |
| SyncPlay 一起看 | 需要 SyncPlay 协议与公共服务器 | 未实现 |
| DLNA 投屏 | SSDP 发现 + AVTransport SOAP | 已实现（基础） |
| 系统代理 | iOS 9 无公开全局代理 API | 仅镜像/自定义域名 |
| 外部播放器 | 可复制链接 / 网页播放兜底 | 部分支持 |

## 3. 工程结构

```
ios/
  AppDelegate.m              根 Tab、主题、URL Scheme、更新检查
  KLTheme / KLComponents     主题与无第三方 UI 组件
  KLHttp                     NSURLSession（信任旧证书、JSON/表单/下载）
  KLImageLoader              内存 + 磁盘图片缓存，3 并发
  KLStore                    NSUserDefaults + JSON 存储（历史/追番/规则）
  Models/KLModels            番剧/剧集/规则/历史/弹幕模型
  Core/KLBangumiAPI          Bangumi API + 镜像/自定义线路
  Core/KLRuleEngine          libxml2 XPath + API JSONPath + 规则搜索/章节
  Core/KLVideoResolver       WKWebView 嗅探 m3u8/mp4（含 legacy iframe）
  Core/KLDanmakuAPI          弹弹Play / B 站 / 本地缓存
  Core/KLWebDAV              备份/恢复/双向合并
  Core/KLDownloadManager     HLS/MP4 下载、AES 解密、本地播放列表
  Core/KLDlnaController      SSDP 发现 + AVTransport 投屏
  Core/KLUpdater             update.json + IPA 安装 + 重启
  UI/...                     时间表、搜索、详情、选源、剧集、播放器、追番、历史、规则、设置
  Resources/rules/           内置规则（AGE/7sefun/giriGiriLove/mutefun）
```

## 4. iOS 9 兼容性要点

- `TARGET=iphone:clang:9.3:9.0`、`ARCHS=armv7`、`USE_MODULES=0`、`iPhoneOS9.3.sdk`。
- 使用 `libxml2`（HTML 解析 + XPath）和 `JavaScriptCore` 之外的纯原生实现；无 Swift/Flutter。
- 不使用 SwiftUI、Combine、SceneDelegate、Diffable Data Source、CryptoKit、PDFKit。
- `NSTimer` 使用 target/selector（iOS 9 无 block 版）；`NSURLSession` 信任旧根证书。
- `AVURLAssetHTTPHeaderFieldsKey` 传递 Referer/UA；失败时自动提示网页播放。
- WKWebView 注入脚本兼容 iOS 9 WebKit；不使用 `evaluateJavaScript` 的新回调形式。
- 图标与 UI 采用手写 frame/AutoResizing，避免 Auto Layout 在 4S 上的开销。
- 弹幕层 30 fps 单视图绘制，限制同屏数量与字号，避免 UILabel 数量爆炸。

## 5. 待验证 / 已知风险

1. **尚未完成真机与 CI 构建验证**：本报告生成时代码已写完，但还没有 Actions 运行结果与 armv7 IPA。
2. **libxml2 链接**：需确认 iPhoneOS9.3.sdk 的 `libxml2.tbd` 与头文件路径；CI 已加入 `-I$(THEOS)/sdks/iPhoneOS9.3.sdk/usr/include/libxml2`。
3. **弹弹Play 凭据**：上游在 CI 注入 secret；本项目默认走 B 站公开接口，弹弹需要在设置中填写 AppId/Secret。
4. **B 站接口**：`comment.bilibili.com/{cid}.xml` 可能受风控；番剧搜索可能返回 `-412`，需要真机验证并按需增加 Cookie/WBI。
5. **规则站点**：内置规则可能失效或需要验证码；规则商店的 raw.githubusercontent 在部分地区不可达，已提供 ghfast/GitCode 镜像。
6. **HLS 本地播放**：AES-128 分片已解密；未处理 `SAMPLE-AES` / DRM。fMP4 的 `EXT-X-MAP` 已保留 init 段。
7. **历史续播**：保存道路 URL 数组，旧记录缺失时退化为单集。
8. **Anime4K / SyncPlay / DLNA**：明确未实现，不应在发布说明中宣称已支持。

## 6. 下一步

1. 运行 GitHub Actions，修复首个编译/链接错误。
2. 下载 Artifact，用 `inspect_ipa.py` 验证 armv7、版本、资源 `rules/AGE.json`、URL scheme `kazumilite`、entitlements。
3. 真机安装，验证：启动、时间表、规则搜索、内置播放、弹幕、追番、历史、WebDAV、下载、更新。
4. 发布 v1.0.0，更新 `update.json` 的 SHA256 与下载地址。
5. 根据真机结果补：图片识番、DLNA、规则验证码 WebView、HLS 广告过滤开关。
