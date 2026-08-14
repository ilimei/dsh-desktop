import AppKit
import WebKit

@main
enum DSHDesktopMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let controller = MainWindowController()
        self.controller = controller
        installMenu(target: controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { controller?.stopServer() }

    private func installMenu(target: MainWindowController) {
        let root = NSMenu()

        let appItem = NSMenuItem()
        root.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 DSH Desktop", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let update = NSMenuItem(title: "检查 DSH 更新…", action: #selector(MainWindowController.checkForUpdatesFromMenu), keyEquivalent: "")
        update.target = target
        appMenu.addItem(update)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 DSH Desktop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let fileItem = NSMenuItem()
        root.addItem(fileItem)
        let fileMenu = NSMenu(title: "文件")
        let newSession = NSMenuItem(title: "新建会话", action: #selector(MainWindowController.newSession), keyEquivalent: "n")
        newSession.target = target
        fileMenu.addItem(newSession)
        let addWorkspace = NSMenuItem(title: "添加工作区…", action: #selector(MainWindowController.addWorkspace), keyEquivalent: "o")
        addWorkspace.target = target
        fileMenu.addItem(addWorkspace)
        fileMenu.addItem(.separator())
        let restart = NSMenuItem(title: "重新启动 DSH", action: #selector(MainWindowController.restartServer), keyEquivalent: "r")
        restart.keyEquivalentModifierMask = [.command, .option]
        restart.target = target
        fileMenu.addItem(restart)
        fileItem.submenu = fileMenu

        let editItem = NSMenuItem()
        root.addItem(editItem)
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        let viewItem = NSMenuItem()
        root.addItem(viewItem)
        let viewMenu = NSMenu(title: "视图")
        let reload = NSMenuItem(title: "重新载入页面", action: #selector(MainWindowController.reloadWebView), keyEquivalent: "r")
        reload.target = target
        viewMenu.addItem(reload)
        viewMenu.addItem(.separator())
        let fullScreen = NSMenuItem(title: "进入全屏幕", action: #selector(MainWindowController.toggleFullScreen), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        fullScreen.target = target
        viewMenu.addItem(fullScreen)
        viewItem.submenu = viewMenu

        let windowItem = NSMenuItem()
        root.addItem(windowItem)
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "前置全部窗口", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        let helpItem = NSMenuItem()
        root.addItem(helpItem)
        let helpMenu = NSMenu(title: "帮助")
        let help = NSMenuItem(title: "DSH Desktop 帮助", action: #selector(MainWindowController.showHelp), keyEquivalent: "?")
        help.target = target
        helpMenu.addItem(help)
        helpItem.submenu = helpMenu
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = root
    }
}

final class NativeDragBridge: NSObject, WKScriptMessageHandler {
    weak var window: NSWindow?
    weak var controller: MainWindowController?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let action = (message.body as? [String: Any])?["action"] as? String else { return }
        if action == "ready" {
            window?.subtitle = "Web Client 拖拽扩展已加载"
            return
        }
        if action == "close" {
            NSApp.terminate(nil)
            return
        }
        if action == "minimize" {
            window?.miniaturize(nil)
            return
        }
        if action == "proxy:get" {
            controller?.publishProxySettings()
            return
        }
        if action == "proxy:save" {
            controller?.saveProxySettings(message.body as? [String: Any] ?? [:])
            return
        }
        if action == "zoom" {
            window?.performZoom(nil)
            return
        }
        guard action == "drag", let event = NSApp.currentEvent, let window else { return }
        let origin = window.frame.origin
        window.performDrag(with: event)
        window.subtitle = window.frame.origin == origin ? "已连接拖拽桥" : "窗口拖拽正常"
    }
}

final class MainWindowController: NSWindowController, WKNavigationDelegate, WKUIDelegate {
    private let webView: WKWebView
    private let dragBridge: NativeDragBridge
    private var process: Process?
    private var updateProcess: Process?
    private var serverURL: URL?
    private var output = ""
    private var restarting = false
    private var stopping = false
    private var startupBeganAt = Date()

    private var supportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DSH Desktop", isDirectory: true)
    }
    private var dshHomeURL: URL { supportURL.appendingPathComponent("dsh-home", isDirectory: true) }

    init() {
        let bridge = NativeDragBridge()
        let userContent = WKUserContentController()
        userContent.add(bridge, name: "dshDesktopDrag")
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.userContentController = userContent
        webView = WKWebView(frame: .zero, configuration: configuration)
        dragBridge = bridge

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1220, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "DSH Desktop"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovable = false
        window.hasShadow = true
        window.minSize = NSSize(width: 760, height: 520)
        window.backgroundColor = NSColor(calibratedWhite: 0.07, alpha: 1)
        window.center()
        super.init(window: window)
        bridge.window = window
        bridge.controller = self

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        guard let content = window.contentView else { return }
        content.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webView.topAnchor.constraint(equalTo: content.topAnchor),
            webView.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
        showStatus(title: "正在启动 DSH", message: "使用内置运行时，无需等待 npm 安装。", retry: false)
        DispatchQueue.main.async { [weak self] in self?.startServer() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func bundledRuntimeURL() -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("runtime", isDirectory: true)
    }

    private func activeRuntimeURL() -> URL? {
        if let saved = UserDefaults.standard.string(forKey: "activeRuntimePath") {
            let url = URL(fileURLWithPath: saved, isDirectory: true)
            if FileManager.default.fileExists(atPath: dshBinary(in: url).path) { return url }
        }
        return bundledRuntimeURL()
    }

    private func dshBinary(in runtime: URL) -> URL {
        runtime.appendingPathComponent("node_modules/@deepseek-ai/dsh/lib/bin.js")
    }

    private func pluginURL(in runtime: URL) -> URL {
        runtime.appendingPathComponent("node_modules/dsh-desktop-web-client", isDirectory: true)
    }

    private func zenmuxURL(in runtime: URL) -> URL {
        runtime.appendingPathComponent("node_modules/@zenmux/dsh-plugins", isDirectory: true)
    }

    private func prepareProfile(runtime: URL) throws {
        let profile = dshHomeURL.appendingPathComponent("profiles/web", isDirectory: true)
        let modules = profile.appendingPathComponent("node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: modules.appendingPathComponent("@zenmux", isDirectory: true), withIntermediateDirectories: true)

        let package = """
        {"name":"dsh-profile-web","private":true,"dependencies":{},"dsh":{"profile":{"bundles":["@deepseek-ai/dsh-base","@deepseek-ai/dsh-web-app","@zenmux/dsh-plugins","dsh-desktop-web-client"]}}}
        """
        try package.write(to: profile.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        for (name, body) in [("cordis.yml", "[]\n"), ("cordis.patch.yml", "[]\n"), ("pnpm-workspace.yaml", "packages:\n  - .\n\nnodeLinker: hoisted\nautoInstallPeers: false\n")] {
            let url = profile.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) { try body.write(to: url, atomically: true, encoding: .utf8) }
        }
        try replaceLink(at: modules.appendingPathComponent("dsh-desktop-web-client"), target: pluginURL(in: runtime))
        try replaceLink(at: modules.appendingPathComponent("@zenmux/dsh-plugins"), target: zenmuxURL(in: runtime))
    }

    private func replaceLink(at url: URL, target: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) || (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target)
    }

    private func startServer() {
        guard process == nil, let runtime = activeRuntimeURL() else {
            showStatus(title: "缺少 DSH 运行时", message: "请重新下载完整客户端。", retry: true)
            return
        }
        do { try prepareProfile(runtime: runtime) }
        catch { showStatus(title: "无法准备 DSH", message: error.localizedDescription, retry: true); return }

        startupBeganAt = Date()
        output = ""
        stopping = false
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let bin = shellQuote(dshBinary(in: runtime).path)
        task.arguments = ["-l", "-c", "exec node \(bin) web --port 0"]
        task.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        var environment = configuredEnvironment()
        environment["DSH_HOME"] = dshHomeURL.path
        environment["TERM"] = "dumb"
        environment["FORCE_COLOR"] = "0"
        task.environment = environment
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.consume(text) }
        }
        task.terminationHandler = { [weak self] finished in DispatchQueue.main.async { self?.serverEnded(finished.terminationStatus) } }
        do { try task.run(); process = task }
        catch { showStatus(title: "DSH 启动失败", message: error.localizedDescription, retry: true) }
    }

    private func consume(_ text: String) {
        output += text
        if output.count > 96_000 { output.removeFirst(output.count - 96_000) }
        let pattern = #"dsh web:\s+(http://(?:127\.0\.0\.1|localhost):\d+)"#
        guard serverURL == nil, let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range(at: 1), in: output), let url = URL(string: String(output[range])) else { return }
        serverURL = url
        webView.load(URLRequest(url: url))
        let elapsed = Date().timeIntervalSince(startupBeganAt)
        window?.subtitle = String(format: "DSH 已就绪 · %.1f 秒", elapsed)
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in self?.checkForUpdates(automatic: true) }
    }

    func stopServer() {
        guard let task = process else { return }
        stopping = true
        task.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { if task.isRunning { kill(task.processIdentifier, SIGKILL) } }
    }

    @objc func restartServer() {
        restarting = true
        if process == nil { startServer() } else { stopServer() }
    }

    @objc func newSession() {
        webView.evaluateJavaScript("document.querySelector('button[aria-label=\\\"新建会话\\\"]')?.click()")
    }

    @objc func addWorkspace() {
        webView.evaluateJavaScript("document.querySelector('button[aria-label=\\\"添加工作区\\\"]')?.click()")
    }

    @objc func reloadWebView() { webView.reload() }

    @objc func toggleFullScreen() { window?.toggleFullScreen(nil) }

    @objc func showHelp() {
        showAlert(title: "DSH Desktop", message: "原生运行 DSH Web Client。\n⌘N 新建会话 · ⌘R 重新载入 · ⌃⌘F 全屏")
    }

    func publishProxySettings() {
        let defaults = UserDefaults.standard
        let detail: [String: Any] = [
            "enabled": defaults.bool(forKey: "proxyEnabled"),
            "url": defaults.string(forKey: "proxyURL") ?? "",
            "noProxy": defaults.string(forKey: "proxyNoProxy") ?? "localhost,127.0.0.1,::1"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: detail),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.dispatchEvent(new CustomEvent('dsh-desktop-proxy',{detail:\(json)}))")
    }

    func saveProxySettings(_ body: [String: Any]) {
        let defaults = UserDefaults.standard
        defaults.set(body["enabled"] as? Bool ?? false, forKey: "proxyEnabled")
        defaults.set(body["url"] as? String ?? "", forKey: "proxyURL")
        defaults.set(body["noProxy"] as? String ?? "localhost,127.0.0.1,::1", forKey: "proxyNoProxy")
        if body["restart"] as? Bool ?? true { restartServer() }
    }

    private func configuredEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let proxyKeys = ["HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "all_proxy", "no_proxy", "NODE_USE_ENV_PROXY", "GLOBAL_AGENT_HTTP_PROXY"]
        for key in proxyKeys { environment.removeValue(forKey: key) }
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "proxyEnabled"),
              let proxyURL = defaults.string(forKey: "proxyURL")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !proxyURL.isEmpty else { return environment }
        var bypass = (defaults.string(forKey: "proxyNoProxy") ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for required in ["localhost", "127.0.0.1", "::1"] where !bypass.contains(required) { bypass.append(required) }
        let noProxy = bypass.joined(separator: ",")
        for key in ["HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"] { environment[key] = proxyURL }
        environment["NO_PROXY"] = noProxy
        environment["no_proxy"] = noProxy
        environment["NODE_USE_ENV_PROXY"] = "1"
        environment["GLOBAL_AGENT_HTTP_PROXY"] = proxyURL
        return environment
    }

    private func serverEnded(_ status: Int32) {
        process = nil
        serverURL = nil
        if restarting { restarting = false; startServer(); return }
        if stopping { stopping = false; return }
        showStatus(title: "DSH 已停止", message: "进程退出状态：\(status)", retry: true)
    }

    @objc func checkForUpdatesFromMenu() { checkForUpdates(automatic: false) }

    private func checkForUpdates(automatic: Bool) {
        guard updateProcess == nil, let runtime = activeRuntimeURL(), let current = runtimeVersion(runtime) else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-l", "-c", "npm view @deepseek-ai/dsh version --json"]
        task.environment = configuredEnvironment()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.terminationHandler = { [weak self] finished in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let latest = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\"\n \t"))
            DispatchQueue.main.async {
                self?.updateProcess = nil
                guard finished.terminationStatus == 0, let latest, !latest.isEmpty else {
                    if !automatic { self?.showAlert(title: "无法检查更新", message: "请检查网络或 npm 配置。") }
                    return
                }
                if latest == current {
                    if !automatic { self?.showAlert(title: "DSH 已是最新版本", message: current) }
                } else {
                    self?.offerUpdate(from: current, to: latest)
                }
            }
        }
        do { try task.run(); updateProcess = task }
        catch { if !automatic { showAlert(title: "无法检查更新", message: error.localizedDescription) } }
    }

    private func offerUpdate(from current: String, to latest: String) {
        let alert = NSAlert()
        alert.messageText = "发现 DSH 更新"
        alert.informativeText = "\(current) → \(latest)\n下载在后台进行，当前 DSH 可继续使用。"
        alert.addButton(withTitle: "下载更新")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn { downloadUpdate(version: latest) }
    }

    private func downloadUpdate(version: String) {
        let safe = version.replacingOccurrences(of: "/", with: "-")
        let runtime = supportURL.appendingPathComponent("runtimes/\(safe)", isDirectory: true)
        try? FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let prefix = shellQuote(runtime.path)
        task.arguments = ["-l", "-c", "exec npm install --prefix \(prefix) --no-audit --no-fund @deepseek-ai/dsh@\(shellQuote(version)) @zenmux/dsh-plugins@latest"]
        task.environment = configuredEnvironment()
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                self?.updateProcess = nil
                guard let self else { return }
                if finished.terminationStatus == 0 {
                    do {
                        let destination = self.pluginURL(in: runtime)
                        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                        guard let source = Bundle.main.resourceURL?.appendingPathComponent("dsh-desktop-web-client") else { throw CocoaError(.fileNoSuchFile) }
                        try FileManager.default.copyItem(at: source, to: destination)
                        UserDefaults.standard.set(runtime.path, forKey: "activeRuntimePath")
                        let alert = NSAlert()
                        alert.messageText = "DSH 更新已就绪"
                        alert.informativeText = "重新启动 DSH 后使用 \(version)。"
                        alert.addButton(withTitle: "立即重启")
                        alert.addButton(withTitle: "稍后")
                        if alert.runModal() == .alertFirstButtonReturn { self.restartServer() }
                    } catch { self.showAlert(title: "更新安装失败", message: error.localizedDescription) }
                } else {
                    self.showAlert(title: "DSH 更新失败", message: "npm install 退出状态：\(finished.terminationStatus)\n请检查网络或 npm 配置。")
                }
            }
        }
        do { try task.run(); updateProcess = task }
        catch { showAlert(title: "无法开始更新", message: error.localizedDescription) }
    }

    private func runtimeVersion(_ runtime: URL) -> String? {
        let url = runtime.appendingPathComponent("node_modules/@deepseek-ai/dsh/package.json")
        guard let data = try? Data(contentsOf: url), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["version"] as? String
    }

    private func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private func showStatus(title: String, message: String, retry: Bool) {
        let action = retry ? #"<a href="dshdesktop://retry">重新启动</a>"# : #"<div class="pulse"></div>"#
        let html = """
        <!doctype html><meta charset="utf-8"><style>
        :root{color-scheme:light dark}body{margin:0;height:100vh;display:grid;place-items:center;font:15px -apple-system,BlinkMacSystemFont,sans-serif;background:#111215;color:#f4f4f5}main{text-align:center;transform:translateY(-3vh)}
        .mark{margin:auto auto 20px;width:48px;height:48px;border-radius:14px;background:#f4f4f5;color:#17181b;display:grid;place-items:center;font-weight:750}h1{font-size:23px;margin:0 0 9px}p{color:#9297a1;margin:0 0 20px}.pulse{margin:auto;width:8px;height:8px;border-radius:50%;background:#58c779;animation:p 1.2s infinite}a{color:#8ba7ff;text-decoration:none}@keyframes p{50%{opacity:.25;transform:scale(.7)}}
        </style><main><div class="mark">DSH</div><h1>\(title)</h1><p>\(message)</p>\(action)</main>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.request.url?.scheme == "dshdesktop" {
            restartServer()
            decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
        return nil
    }
}
