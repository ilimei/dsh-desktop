# DSH Desktop

`@deepseek-ai/dsh` Web Client 的轻量原生 macOS 客户端。使用 Swift、AppKit 与 WKWebView，界面完全沿用 DSH 原生页面，不重复添加外层侧边栏。

## 功能

- 自动启动本机 `dsh web`
- 自动使用 `--port 0` 并从 DSH 输出发现实际端口
- 完整保留 DSH 原生 Web Client 页面和侧边栏
- 内置 `@deepseek-ai/dsh` 运行时，启动不经过 `npx`
- 内置 `@zenmux/dsh-plugins`
- 内置 Web Client 窗口插件：拖拽、macOS 三色按钮、折叠栏单红点布局
- 原生 macOS 圆角窗口和标准菜单栏
- Codex 风格 DeepSeek 鲸鱼应用图标
- 设置页内置网络代理：支持 HTTP、HTTPS、SOCKS5、直连名单与保存后重启
- 后台检查 DSH 更新，也可从 DSH 菜单手动检查

## 构建

需要 macOS 13 或更高版本、Xcode Command Line Tools、Node.js 与 npm。

```sh
./build.sh
```

产物位于 `dist/DSH Desktop.app`。这是 ad-hoc 签名的本地构建；跨机器分发前应使用 Developer ID 签名并公证。

## 安装

从 [Releases](https://github.com/ilimei/dsh-desktop/releases) 下载 arm64 压缩包，解压后把 `DSH Desktop.app` 移入“应用程序”。当前版本使用系统 Node.js 启动内置 DSH 运行时。
