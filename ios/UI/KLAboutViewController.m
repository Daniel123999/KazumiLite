#import "KLAboutViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLWebViewController.h"

@implementation KLAboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"关于";
    self.view.backgroundColor = [KLTheme background];

    UITextView *text = [[UITextView alloc] initWithFrame:self.view.bounds];
    text.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    text.backgroundColor = [KLTheme background];
    text.textColor = [KLTheme textPrimary];
    text.font = [KLTheme font:13];
    text.editable = NO;
    text.textContainerInset = UIEdgeInsetsMake(16, 16, 24, 16);
    text.text = @"Kazumi Lite 1.0.1 (Build 2)\n\n"
        @"面向 iPhone 4S / iOS 9.3.6 / armv7 的番剧采集与在线观看客户端，"
        @"参考 Predidit/Kazumi 的功能与规则格式，使用 Objective-C + UIKit + Theos 重写。\n\n"
        @"## 已实现\n"
        @"• Bangumi 每日放送、热门、搜索、详情、剧集、评论\n"
        @"• 自定义 XPath / API 规则的搜索、线路与剧集解析\n"
        @"• 规则导入、编辑、导出与 KazumiRules 在线商店\n"
        @"• AVPlayer 原生播放、倍速、进度记忆、自动连播、截图\n"
        @"• 弹幕（弹弹Play / BiliBili / 本地缓存）与屏蔽词、样式设置\n"
        @"• 追番、观看历史、Bangumi Token 同步、WebDAV 备份\n"
        @"• HLS / MP4 离线下载与本地播放\n"
        @"• Gitee / GitHub 应用内更新\n\n"
        @"## iOS 9 限制\n"
        @"• Anime4K 实时超分、一起看（SyncPlay）、DLNA 投屏尚未在此版本提供："
        @"A5 GPU 与系统播放管线无法承载 Anime4K 多 pass 着色器；SyncPlay/DLNA 需要额外的服务端与协议实现。\n"
        @"• 部分视频源使用新版 WebKit/DRM，iPhone 4S 的 WKWebView 可能无法解析，可改用网页播放或换源。\n\n"
        @"## 开源与免责声明\n"
        @"本程序以 GPL-3.0 发布，规则格式与部分解析思路来自 Kazumi（GPL-3.0）。"
        @"本项目不提供、不存储任何视频内容，所有视频来自第三方规则站点；"
        @"请遵守所在地法律法规，支持正版。因使用本项目产生的数据与缓存应在 24 小时内清除。\n\n"
        @"Bangumi 数据来自 api.bgm.tv / next.bgm.tv；弹幕来自 弹弹play 与 BiliBili 公开接口；"
        @"Anime4K 名称与规则仓库归原作者所有。\n\n"
        @"项目地址：https://github.com/Daniel123999/KazumiLite\n"
        @"上游项目：https://github.com/Predidit/Kazumi";

    [self.view addSubview:text];
}

@end
