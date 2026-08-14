window.__ModuleLoader__.load({
  id: "dsh-desktop-web-client",
  factory: (require) => {
    const module = { exports: {} };
    const exports = module.exports;
    const React = require("react");
    const { jsx, jsxs } = require("react/jsx-runtime");

    function ProxySettings() {
      const [settings, setSettings] = React.useState({ enabled: false, url: "", noProxy: "localhost,127.0.0.1,::1" });
      const [status, setStatus] = React.useState("");
      const bridge = window.webkit?.messageHandlers?.dshDesktopDrag;

      React.useEffect(() => {
        const receive = (event) => setSettings({
          enabled: Boolean(event.detail?.enabled),
          url: event.detail?.url || "",
          noProxy: event.detail?.noProxy || "localhost,127.0.0.1,::1"
        });
        window.addEventListener("dsh-desktop-proxy", receive);
        bridge?.postMessage({ action: "proxy:get" });
        return () => window.removeEventListener("dsh-desktop-proxy", receive);
      }, []);

      const save = (next, restart = true) => {
        bridge?.postMessage({ action: "proxy:save", ...next, restart });
        setSettings(next);
        setStatus(restart ? "已保存，正在重新启动 DSH…" : "已保存");
      };

      return jsxs("section", { className: "dsh-desktop-proxy-page", children: [
        jsx("h2", { children: "网络代理" }),
        jsx("p", { className: "dsh-desktop-proxy-hint", children: "为 DSH 模型请求、插件和更新设置进程级代理。保存后会重新启动 DSH。" }),
        jsxs("label", { className: "dsh-desktop-proxy-switch", children: [
          jsx("input", { type: "checkbox", checked: settings.enabled, onChange: (event) => setSettings({ ...settings, enabled: event.target.checked }) }),
          jsx("span", { children: "启用网络代理" })
        ] }),
        jsxs("label", { className: "dsh-desktop-proxy-field", children: [
          jsx("span", { children: "代理地址" }),
          jsx("input", {
            value: settings.url,
            disabled: !settings.enabled,
            placeholder: "http://127.0.0.1:7890",
            spellCheck: false,
            onChange: (event) => setSettings({ ...settings, url: event.target.value })
          })
        ] }),
        jsxs("label", { className: "dsh-desktop-proxy-field", children: [
          jsx("span", { children: "不走代理" }),
          jsx("input", {
            value: settings.noProxy,
            placeholder: "localhost,127.0.0.1,::1",
            spellCheck: false,
            onChange: (event) => setSettings({ ...settings, noProxy: event.target.value })
          })
        ] }),
        jsx("p", { className: "dsh-desktop-proxy-note", children: "支持 http://、https:// 和 socks5:// 地址；本机回环地址始终保持直连。" }),
        jsxs("div", { className: "dsh-desktop-proxy-actions", children: [
          jsx("button", {
            type: "button",
            className: "dsh-desktop-proxy-secondary",
            onClick: () => save({ enabled: false, url: "", noProxy: "localhost,127.0.0.1,::1" }),
            children: "恢复直连"
          }),
          jsx("button", {
            type: "button",
            className: "dsh-desktop-proxy-primary",
            disabled: settings.enabled && !settings.url.trim(),
            onClick: () => save({ ...settings, url: settings.url.trim(), noProxy: settings.noProxy.trim() }),
            children: "保存并重启 DSH"
          })
        ] }),
        status && jsx("div", { className: "dsh-desktop-proxy-status", children: status })
      ] });
    }

    function GatewaySettings() {
      const [baseURL, setBaseURL] = React.useState("");
      const [apiKey, setAPIKey] = React.useState("");
      const [hasAPIKey, setHasAPIKey] = React.useState(false);
      const [status, setStatus] = React.useState("");
      const bridge = window.webkit?.messageHandlers?.dshDesktopDrag;

      React.useEffect(() => {
        const receive = (event) => {
          setBaseURL(event.detail?.deepseekBaseURL || "");
          setHasAPIKey(Boolean(event.detail?.hasAPIKey));
        };
        window.addEventListener("dsh-desktop-gateway", receive);
        bridge?.postMessage({ action: "gateway:get" });
        return () => window.removeEventListener("dsh-desktop-gateway", receive);
      }, []);

      const normalized = baseURL.trim().replace(/\/+$/, "");
      let valid = true;
      if (normalized) {
        try {
          const parsed = new URL(normalized);
          valid = (parsed.protocol === "http:" || parsed.protocol === "https:") && !parsed.username && !parsed.password;
        } catch { valid = false; }
      }
      const save = (value, clearAPIKey = false) => {
        bridge?.postMessage({ action: "gateway:save", deepseekBaseURL: value, apiKey, clearAPIKey, restart: true });
        setBaseURL(value);
        if (clearAPIKey) setHasAPIKey(false);
        else if (apiKey.trim()) setHasAPIKey(true);
        setAPIKey("");
        setStatus("已保存，正在重新启动 DSH…");
      };

      return jsxs("section", { className: "dsh-desktop-proxy-page", children: [
        jsx("h2", { children: "LLM Gateway" }),
        jsx("p", { className: "dsh-desktop-proxy-hint", children: "设置 DeepSeek 模型请求使用的 Base URL。保存后会重新启动 DSH。" }),
        jsxs("label", { className: "dsh-desktop-proxy-field", children: [
          jsx("span", { children: "DeepSeek Base URL" }),
          jsx("input", {
            value: baseURL,
            placeholder: "https://api.deepseek.com",
            spellCheck: false,
            autoCapitalize: "none",
            onChange: (event) => { setBaseURL(event.target.value); setStatus(""); }
          })
        ] }),
        jsx("p", { className: "dsh-desktop-proxy-note", children: valid ? "留空使用 DeepSeek 官方默认地址；DSH 会自动追加 /chat/completions。" : "请输入有效的 http:// 或 https:// 地址，且不要包含用户名或密码。" }),
        jsxs("label", { className: "dsh-desktop-proxy-field", children: [
          jsxs("span", { children: ["DeepSeek API Key", hasAPIKey && jsx("small", { className: "dsh-desktop-key-state", children: "已存入钥匙串" })] }),
          jsx("input", {
            type: "password",
            value: apiKey,
            placeholder: hasAPIKey ? "已配置；留空保持不变" : "输入 API Key",
            spellCheck: false,
            autoComplete: "new-password",
            onChange: (event) => { setAPIKey(event.target.value); setStatus(""); }
          })
        ] }),
        jsx("p", { className: "dsh-desktop-proxy-note", children: "API Key 安全存储在 macOS 钥匙串中，不会写入应用偏好设置或日志。" }),
        jsxs("div", { className: "dsh-desktop-proxy-actions", children: [
          hasAPIKey && jsx("button", {
            type: "button",
            className: "dsh-desktop-proxy-secondary",
            onClick: () => save(normalized, true),
            children: "清除 API Key"
          }),
          jsx("button", {
            type: "button",
            className: "dsh-desktop-proxy-secondary",
            onClick: () => save(""),
            children: "恢复默认"
          }),
          jsx("button", {
            type: "button",
            className: "dsh-desktop-proxy-primary",
            disabled: !valid,
            onClick: () => save(normalized),
            children: "保存并重启 DSH"
          })
        ] }),
        status && jsx("div", { className: "dsh-desktop-proxy-status", children: status })
      ] });
    }

    function apply(ctx) {
      ctx.effect(() => {
        const bridge = window.webkit?.messageHandlers?.dshDesktopDrag;
        if (bridge === undefined) return () => {};
        bridge.postMessage({ action: "ready" });

        const style = document.createElement("style");
        style.dataset.plugin = "dsh-desktop-web-client";
        style.textContent = `
          #dsh-desktop-window-controls {
            position: fixed;
            z-index: 2147483647;
            top: 12px;
            left: 12px;
            display: flex;
            gap: 8px;
            align-items: center;
            padding: 3px;
          }
          #dsh-desktop-window-controls button {
            width: 14px;
            height: 14px;
            min-width: 14px;
            padding: 0;
            border: 0;
            border-radius: 50%;
            box-shadow: inset 0 0 0 .5px rgb(0 0 0 / 24%);
            cursor: default;
          }
          #dsh-desktop-window-controls button:nth-child(1) { background: #ff5f57; }
          #dsh-desktop-window-controls button:nth-child(2) { background: #febc2e; }
          #dsh-desktop-window-controls button:nth-child(3) { background: #28c840; }
          #dsh-desktop-window-controls:hover button::after {
            display: block;
            color: rgb(0 0 0 / 58%);
            font: 700 10px/14px -apple-system, sans-serif;
            text-align: center;
          }
          #dsh-desktop-window-controls:hover button:nth-child(1)::after { content: "×"; }
          #dsh-desktop-window-controls:hover button:nth-child(2)::after { content: "−"; }
          #dsh-desktop-window-controls:hover button:nth-child(3)::after { content: "+"; }
          body:has(.hHd-Xa_collapsed) #dsh-desktop-window-controls button:not(:first-child),
          body:has([class*="_collapsed"][class*="_root"]) #dsh-desktop-window-controls button:not(:first-child) {
            display: none;
          }
          body:has(.hHd-Xa_collapsed) #dsh-desktop-window-controls,
          body:has([class*="_collapsed"][class*="_root"]) #dsh-desktop-window-controls {
            left: 16px;
          }
          .hHd-Xa_logoRow,
          [class*="_sidebarCol"] > div > [class*="_logoRow"] {
            height: 72px !important;
            padding-top: 20px !important;
          }
          .hHd-Xa_collapsed .hHd-Xa_logoRow,
          [class*="_collapsed"] > [class*="_logoRow"] {
            height: 48px !important;
            padding-top: 12px !important;
          }
          .dsh-desktop-proxy-page {
            box-sizing: border-box;
            width: min(680px, 100%);
            margin: 0 auto;
            padding: 36px 28px;
            color: var(--dsw-alias-label-primary);
          }
          .dsh-desktop-proxy-page h2 { margin: 0 0 8px; font-size: 24px; font-weight: 600; }
          .dsh-desktop-proxy-hint, .dsh-desktop-proxy-note { color: var(--dsw-alias-label-secondary); line-height: 1.55; }
          .dsh-desktop-proxy-hint { margin: 0 0 28px; }
          .dsh-desktop-proxy-note { margin: 8px 0 24px; font-size: 12px; }
          .dsh-desktop-proxy-switch { display: flex; align-items: center; gap: 10px; margin-bottom: 22px; }
          .dsh-desktop-proxy-switch input { width: 16px; height: 16px; accent-color: var(--dsw-alias-brand-primary); }
          .dsh-desktop-proxy-field { display: grid; gap: 8px; margin: 16px 0; font-size: 13px; font-weight: 500; }
          .dsh-desktop-proxy-field input {
            box-sizing: border-box;
            width: 100%; height: 42px; padding: 0 13px;
            border: 1px solid var(--dsw-alias-border-l2); border-radius: 10px;
            outline: none; color: var(--dsw-alias-label-primary); background: var(--dsw-alias-bg-layer-2);
            font: 13px ui-monospace, SFMono-Regular, Menlo, monospace;
          }
          .dsh-desktop-proxy-field input:focus { border-color: var(--dsw-alias-brand-primary); }
          .dsh-desktop-proxy-field input:disabled { opacity: .45; }
          .dsh-desktop-key-state { margin-left: 8px; color: var(--dsw-alias-state-success-primary); font-size: 11px; font-weight: 500; }
          .dsh-desktop-proxy-actions { display: flex; justify-content: flex-end; gap: 10px; }
          .dsh-desktop-proxy-actions button { height: 38px; padding: 0 16px; border-radius: 19px; border: 0; cursor: pointer; }
          .dsh-desktop-proxy-primary { background: var(--dsw-alias-button-primary-fill); color: var(--dsw-alias-label-primary-foreground); }
          .dsh-desktop-proxy-secondary { background: var(--dsw-alias-button-elevated-fill); color: var(--dsw-alias-label-primary); }
          .dsh-desktop-proxy-actions button:disabled { opacity: .4; cursor: default; }
          .dsh-desktop-proxy-status { margin-top: 14px; text-align: right; color: var(--dsw-alias-state-success-primary); font-size: 12px; }
          #dsh-desktop-drag-region {
            position: fixed;
            z-index: 2147483646;
            top: 0;
            left: 72px;
            right: 0;
            height: 36px;
            cursor: default;
            user-select: none;
            -webkit-user-select: none;
            touch-action: none;
          }
        `;

        const controls = document.createElement("div");
        controls.id = "dsh-desktop-window-controls";
        controls.setAttribute("aria-label", "窗口控制");
        for (const [action, label] of [["close", "关闭"], ["minimize", "最小化"], ["zoom", "缩放"]]) {
          const button = document.createElement("button");
          button.type = "button";
          button.setAttribute("aria-label", label);
          button.addEventListener("click", () => bridge.postMessage({ action }));
          controls.appendChild(button);
        }

        const region = document.createElement("div");
        region.id = "dsh-desktop-drag-region";
        region.setAttribute("aria-hidden", "true");
        region.addEventListener("pointerdown", (event) => {
          if (event.button !== 0) return;
          bridge.postMessage({ action: "drag" });
        });
        region.addEventListener("dblclick", () => {
          bridge.postMessage({ action: "zoom" });
        });

        document.head.appendChild(style);
        document.body.appendChild(controls);
        document.body.appendChild(region);
        return () => {
          region.remove();
          controls.remove();
          style.remove();
        };
      }, "dsh-desktop: native titlebar drag region");

      ctx.slots.inject("settings.section", () => ctx.slots.register({
        name: "settings.section",
        id: "desktop-network-proxy",
        order: 18,
        label: () => "网络代理"
      }, ProxySettings));
      ctx.slots.inject("settings.section", () => ctx.slots.register({
        name: "settings.section",
        id: "desktop-llm-gateway",
        order: 19,
        label: () => "LLM Gateway"
      }, GatewaySettings));
    }

    exports.apply = apply;
    exports.inject = ["slots"];
    return module.exports;
  }
});
