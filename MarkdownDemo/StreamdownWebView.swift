//
//  StreamdownWebView.swift
//  MarkdownDemo
//
//  Created by lmc on 12/31/25.
//

import SwiftUI
import WebKit

/// A SwiftUI wrapper for WKWebView that renders Markdown using Streamdown library
struct StreamdownWebView: UIViewRepresentable {
    let markdown: String
    var isAnimating: Bool = false
    var theme: StreamdownTheme = .auto
    var enableScroll: Bool = true  // 是否启用内部滚动
    @Binding var contentHeight: CGFloat
    @Binding var isReady: Bool
    
    enum StreamdownTheme: String {
        case light = "light"
        case dark = "dark"
        case auto = "auto"
    }
    
    // Convenience initializer without bindings (standalone mode, scroll enabled)
    init(markdown: String, isAnimating: Bool = false, theme: StreamdownTheme = .auto) {
        self.markdown = markdown
        self.isAnimating = isAnimating
        self.theme = theme
        self.enableScroll = true  // 独立模式，启用滚动
        self._contentHeight = .constant(0)
        self._isReady = .constant(false)
    }
    
    // Initializer with height binding only (embedded mode, scroll disabled)
    init(markdown: String, isAnimating: Bool = false, theme: StreamdownTheme = .auto, contentHeight: Binding<CGFloat>) {
        self.markdown = markdown
        self.isAnimating = isAnimating
        self.theme = theme
        self.enableScroll = false  // 嵌入模式，禁用滚动
        self._contentHeight = contentHeight
        self._isReady = .constant(false)
    }
    
    // Full initializer with both bindings (embedded mode, scroll disabled)
    init(markdown: String, isAnimating: Bool = false, theme: StreamdownTheme = .auto, contentHeight: Binding<CGFloat>, isReady: Binding<Bool>) {
        self.markdown = markdown
        self.isAnimating = isAnimating
        self.theme = theme
        self.enableScroll = false  // 嵌入模式，禁用滚动
        self._contentHeight = contentHeight
        self._isReady = isReady
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let pool = StreamdownWebViewPool.shared
        
        // Try to get a prewarmed WebView from the pool
        if let prewarmedWebView = pool.dequeue() {
            // Add message handlers to the prewarmed WebView
            let contentController = prewarmedWebView.configuration.userContentController
            contentController.add(context.coordinator, name: "heightChanged")
            contentController.add(context.coordinator, name: "contentReady")
            
            // 根据模式设置滚动
            prewarmedWebView.scrollView.isScrollEnabled = enableScroll
            
            prewarmedWebView.navigationDelegate = context.coordinator
            context.coordinator.webView = prewarmedWebView
            context.coordinator.pendingMarkdown = markdown
            context.coordinator.pendingIsAnimating = isAnimating
            context.coordinator.usePrewarmed = true
            
            // The prewarmed WebView should already have pageReady = true
            // Just need to update the markdown content
            checkAndUpdatePrewarmedWebView(prewarmedWebView, context: context)
            
            return prewarmedWebView
        }
        
        // Fallback: create new WebView if pool is empty
        return createNewWebView(context: context)
    }
    
    private func checkAndUpdatePrewarmedWebView(_ webView: WKWebView, context: Context) {
        // Check if page is already ready
        webView.evaluateJavaScript("window.pageReady === true") { [weak webView] result, _ in
            guard let webView = webView else { return }
            
            if let ready = result as? Bool, ready {
                context.coordinator.isPageReady = true
                
                // 预热的 WebView 已经 ready
                // 先更新内容，更新完成后再通知 ready（避免显示空白）
                let escapedMarkdown = self.escapeForJS(self.markdown)
                let script = "if(typeof window.updateMarkdown === 'function') { window.updateMarkdown(`\(escapedMarkdown)`, \(self.isAnimating)); }"
                webView.evaluateJavaScript(script) { _, _ in
                    // 内容更新后获取高度并通知 ready
                    context.coordinator.requestHeightAndNotifyReady(webView: webView)
                }
            } else {
                // Page not ready yet, wait for navigation delegate
                context.coordinator.isPageReady = false
            }
        }
    }
    
    private func createNewWebView(context: Context) -> WKWebView {
        let pool = StreamdownWebViewPool.shared
        let configuration = pool.createConfiguration()
        
        // Add script message handlers
        let contentController = configuration.userContentController
        contentController.add(context.coordinator, name: "heightChanged")
        contentController.add(context.coordinator, name: "contentReady")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = enableScroll  // 根据模式设置滚动
        webView.navigationDelegate = context.coordinator
        
        context.coordinator.webView = webView
        context.coordinator.pendingMarkdown = markdown
        context.coordinator.pendingIsAnimating = isAnimating
        context.coordinator.usePrewarmed = false
        
        // Load HTML
        let html = generateHTML(initialMarkdown: markdown, isAnimating: isAnimating)
        
        if let baseURL = pool.getBaseURL() {
            webView.loadHTMLString(html, baseURL: baseURL)
        } else if let resourcePath = Bundle.main.path(forResource: "streamdown-lite", ofType: "js", inDirectory: "StreamdownBundle"),
                  let baseURL = URL(fileURLWithPath: resourcePath).deletingLastPathComponent() as URL? {
            webView.loadHTMLString(html, baseURL: baseURL)
        } else if let resourcePath = Bundle.main.path(forResource: "streamdown-bundle", ofType: "js", inDirectory: "StreamdownBundle"),
                  let baseURL = URL(fileURLWithPath: resourcePath).deletingLastPathComponent() as URL? {
            webView.loadHTMLString(html, baseURL: baseURL)
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only update if page is ready
        guard context.coordinator.isPageReady else {
            context.coordinator.pendingMarkdown = markdown
            context.coordinator.pendingIsAnimating = isAnimating
            return
        }
        
        // Update markdown content via JavaScript
        let escapedMarkdown = escapeForJS(markdown)
        let script = "if(typeof window.updateMarkdown === 'function') { window.updateMarkdown(`\(escapedMarkdown)`, \(isAnimating)); }"
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("JavaScript error: \(error)")
            }
        }
    }
    
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        // Remove message handlers to prevent leaks
        let contentController = webView.configuration.userContentController
        contentController.removeScriptMessageHandler(forName: "heightChanged")
        contentController.removeScriptMessageHandler(forName: "contentReady")
        
        // Optionally recycle the WebView back to pool
        // StreamdownWebViewPool.shared.recycle(webView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(heightBinding: $contentHeight, isReadyBinding: $isReady)
    }
    
    private func escapeForJS(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
    
    private func generateHTML(initialMarkdown: String, isAnimating: Bool) -> String {
        let themeMode = theme.rawValue
        let escapedMarkdown = escapeForJS(initialMarkdown)
        
        // 使用 Pool 缓存的 JS 资源
        let pool = StreamdownWebViewPool.shared
        let bundledJS = pool.getCachedJS()
        
        let jsTag: String
        if let js = bundledJS {
            jsTag = "<script>\(js)</script>"
        } else {
            jsTag = "<script src=\"streamdown-bundle.js\"></script>"
        }
        
        // 初始 HTML 只包含内联基础样式，增强 CSS 将通过 JavaScript 延迟注入
        // 这样可以快速显示内容，然后异步加载丰富样式
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>Streamdown</title>
            
            <style>
                * {
                    -webkit-tap-highlight-color: transparent;
                    box-sizing: border-box;
                }
                
                :root {
                    color-scheme: light dark;
                }
                
                html, body {
                    margin: 0;
                    padding: 0;
                    overflow: hidden;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    padding: 16px;
                    background: transparent;
                    color: #1a1a1a;
                    line-height: 1.6;
                }
                
                @media (prefers-color-scheme: dark) {
                    body { color: #e5e5e5; }
                }
                
                #root {
                    min-height: 50px;
                }
                
                #root h1 {
                    font-size: 1.8em;
                    font-weight: 700;
                    margin: 0.5em 0;
                    border-bottom: 1px solid #e5e5e5;
                    padding-bottom: 0.3em;
                }
                
                @media (prefers-color-scheme: dark) {
                    #root h1 { border-bottom-color: #333; }
                }
                
                #root h2 {
                    font-size: 1.4em;
                    font-weight: 600;
                    margin: 0.7em 0;
                    border-bottom: 1px solid #e5e5e5;
                    padding-bottom: 0.3em;
                }
                
                @media (prefers-color-scheme: dark) {
                    #root h2 { border-bottom-color: #333; }
                }
                
                #root h3 {
                    font-size: 1.2em;
                    font-weight: 600;
                    margin: 0.8em 0;
                }
                
                #root p {
                    margin: 0.8em 0;
                }
                
                #root code {
                    background: #f4f4f4;
                    padding: 0.2em 0.4em;
                    border-radius: 4px;
                    font-family: 'SF Mono', Menlo, Monaco, monospace;
                    font-size: 0.85em;
                }
                
                @media (prefers-color-scheme: dark) {
                    #root code { background: #2d2d2d; }
                }
                
                #root pre {
                    background: #f4f4f4;
                    padding: 12px;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin: 0.8em 0;
                    font-size: 0.85em;
                }
                
                @media (prefers-color-scheme: dark) {
                    #root pre { background: #1e1e1e; }
                }
                
                #root pre code {
                    background: transparent;
                    padding: 0;
                }
                
                /* highlight.js theme - GitHub-like */
                .hljs { display: block; overflow-x: auto; color: #24292e; }
                .hljs-comment, .hljs-quote { color: #6a737d; font-style: italic; }
                .hljs-keyword, .hljs-selector-tag { color: #d73a49; font-weight: 600; }
                .hljs-literal, .hljs-number, .hljs-tag .hljs-attr { color: #005cc5; }
                .hljs-string, .hljs-doctag, .hljs-regexp { color: #032f62; }
                .hljs-title, .hljs-section, .hljs-selector-id { color: #6f42c1; font-weight: 600; }
                .hljs-subst { color: #24292e; font-weight: normal; }
                .hljs-type, .hljs-class .hljs-title { color: #6f42c1; }
                .hljs-variable, .hljs-template-variable { color: #e36209; }
                .hljs-name, .hljs-attribute { color: #22863a; }
                .hljs-symbol, .hljs-bullet, .hljs-link { color: #005cc5; }
                .hljs-built_in, .hljs-builtin-name { color: #005cc5; }
                .hljs-meta { color: #6a737d; font-weight: 600; }
                .hljs-deletion { background: #ffeef0; color: #b31d28; }
                .hljs-addition { background: #e6ffed; color: #22863a; }
                .hljs-emphasis { font-style: italic; }
                .hljs-strong { font-weight: bold; }
                @media (prefers-color-scheme: dark) {
                    .hljs { color: #c9d1d9; }
                    .hljs-comment, .hljs-quote { color: #8b949e; }
                    .hljs-keyword, .hljs-selector-tag { color: #ff7b72; }
                    .hljs-literal, .hljs-number, .hljs-tag .hljs-attr { color: #79c0ff; }
                    .hljs-string, .hljs-doctag, .hljs-regexp { color: #a5d6ff; }
                    .hljs-title, .hljs-section, .hljs-selector-id { color: #d2a8ff; }
                    .hljs-subst { color: #c9d1d9; }
                    .hljs-type, .hljs-class .hljs-title { color: #d2a8ff; }
                    .hljs-variable, .hljs-template-variable { color: #ffa657; }
                    .hljs-name, .hljs-attribute { color: #7ee787; }
                    .hljs-symbol, .hljs-bullet, .hljs-link { color: #79c0ff; }
                    .hljs-built_in, .hljs-builtin-name { color: #79c0ff; }
                    .hljs-meta { color: #8b949e; }
                    .hljs-deletion { background: #490202; color: #ffdcd7; }
                    .hljs-addition { background: #04260f; color: #aff5b4; }
                }
                
                #root ul, #root ol {
                    padding-left: 1.5em;
                    margin: 0.8em 0;
                }
                
                #root li {
                    margin: 0.3em 0;
                }
                
                #root blockquote {
                    border-left: 4px solid #ddd;
                    margin: 0.8em 0;
                    padding-left: 1em;
                    color: #666;
                }
                
                @media (prefers-color-scheme: dark) {
                    #root blockquote {
                        border-left-color: #444;
                        color: #aaa;
                    }
                }
                
                #root table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 0.8em 0;
                    font-size: 0.9em;
                    display: block;
                    overflow-x: auto;
                }
                
                #root th, #root td {
                    border: 1px solid #ddd;
                    padding: 8px 12px;
                    text-align: left;
                }
                
                @media (prefers-color-scheme: dark) {
                    #root th, #root td {
                        border-color: #444;
                    }
                }
                
                #root th {
                    background: #f4f4f4;
                    font-weight: 600;
                }
                
                @media (prefers-color-scheme: dark) {
                    #root th { background: #2d2d2d; }
                }
                
                #root a {
                    color: #0066cc;
                    text-decoration: none;
                }
                
                @media (prefers-color-scheme: dark) {
                    #root a { color: #58a6ff; }
                }
                
                #root img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                }
                
                #root hr {
                    border: none;
                    border-top: 1px solid #e5e5e5;
                    margin: 1.5em 0;
                }
                
                @media (prefers-color-scheme: dark) {
                    #root hr { border-top-color: #333; }
                }
                
                #root strong {
                    font-weight: 600;
                }
                
                #root em {
                    font-style: italic;
                }
                
                #root del {
                    text-decoration: line-through;
                    color: #999;
                }
            </style>
        </head>
        <body>
            <div id="root"></div>
            
            <script>
                window.setInitialMarkdown && window.setInitialMarkdown(`\(escapedMarkdown)`, \(isAnimating));
            </script>
            
            \(jsTag)
            
            <script>
                if (!window.pageReady && typeof window.initStreamdown === 'function') {
                    window.initStreamdown();
                }
                
                (function() {
                    var theme = '\(themeMode)';
                    if (theme === 'dark') {
                        document.documentElement.style.colorScheme = 'dark';
                    } else if (theme === 'light') {
                        document.documentElement.style.colorScheme = 'light';
                    }
                })();
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var isPageReady = false
        var pendingMarkdown: String?
        var pendingIsAnimating: Bool = false
        var usePrewarmed: Bool = false
        weak var webView: WKWebView?
        var heightBinding: Binding<CGFloat>
        var isReadyBinding: Binding<Bool>
        
        init(heightBinding: Binding<CGFloat>, isReadyBinding: Binding<Bool>) {
            self.heightBinding = heightBinding
            self.isReadyBinding = isReadyBinding
            super.init()
        }
        
        // MARK: - WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightChanged",
               let body = message.body as? [String: Any],
               let height = body["height"] as? CGFloat {
                DispatchQueue.main.async {
                    if abs(self.heightBinding.wrappedValue - height) > 1 {
                        self.heightBinding.wrappedValue = height
                    }
                }
            } else if message.name == "contentReady" {
                DispatchQueue.main.async {
                    self.isReadyBinding.wrappedValue = true
                }
            }
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // For prewarmed WebViews, the content might already be updated
            // so we just need to check page ready status
            checkPageReady(webView: webView, attempts: 0)
        }
        
        private func checkPageReady(webView: WKWebView, attempts: Int) {
            guard attempts < 50 else {
                print("Page ready timeout")
                isPageReady = true
                sendPendingUpdate(webView: webView)
                notifyContentReady()
                return
            }
            
            webView.evaluateJavaScript("window.pageReady === true") { [weak self] result, _ in
                guard let self = self else { return }
                
                if let ready = result as? Bool, ready {
                    self.isPageReady = true
                    self.sendPendingUpdate(webView: webView)
                    self.requestHeightAndNotifyReady(webView: webView)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.checkPageReady(webView: webView, attempts: attempts + 1)
                    }
                }
            }
        }
        
        private func sendPendingUpdate(webView: WKWebView) {
            guard let markdown = pendingMarkdown else { return }
            
            let escapedMarkdown = markdown
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            
            let script = "if(typeof window.updateMarkdown === 'function') { window.updateMarkdown(`\(escapedMarkdown)`, \(pendingIsAnimating)); }"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        func requestHeightAndNotifyReady(webView: WKWebView) {
            // 第一次获取高度
            requestHeightWithRetry(webView: webView, attempts: 0, lastHeight: 0)
        }
        
        private func requestHeightWithRetry(webView: WKWebView, attempts: Int, lastHeight: CGFloat) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                guard let self = self else { return }
                
                if let height = result as? CGFloat, height > 0 {
                    DispatchQueue.main.async {
                        self.heightBinding.wrappedValue = height
                    }
                    
                    // 如果高度还在变化，或者尝试次数不够，继续重试
                    // 最多重试 5 次，每次间隔 50ms
                    if attempts < 5 && (attempts < 2 || abs(height - lastHeight) > 1) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.requestHeightWithRetry(webView: webView, attempts: attempts + 1, lastHeight: height)
                        }
                    } else {
                        // 高度稳定了，通知 ready
                        self.notifyContentReady()
                    }
                } else {
                    // 获取失败，直接通知 ready
                    self.notifyContentReady()
                }
            }
        }
        
        /// 只获取高度，不触发 isReady（用于预热 WebView 更新内容后）
        func requestHeight(webView: WKWebView) {
            requestHeightOnly(webView: webView, attempts: 0, lastHeight: 0)
        }
        
        private func requestHeightOnly(webView: WKWebView, attempts: Int, lastHeight: CGFloat) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                guard let self = self else { return }
                if let height = result as? CGFloat, height > 0 {
                    DispatchQueue.main.async {
                        if abs(self.heightBinding.wrappedValue - height) > 1 {
                            self.heightBinding.wrappedValue = height
                        }
                    }
                    
                    // 继续重试直到高度稳定
                    if attempts < 5 && (attempts < 2 || abs(height - lastHeight) > 1) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.requestHeightOnly(webView: webView, attempts: attempts + 1, lastHeight: height)
                        }
                    }
                }
            }
        }
        
        private func notifyContentReady() {
            DispatchQueue.main.async {
                self.isReadyBinding.wrappedValue = true
                
                // 延迟注入增强 CSS（内容已显示，此时加载不会阻塞渲染）
                self.injectEnhancedCSSDeferred()
            }
        }
        
        /// 延迟注入增强 CSS 样式
        private func injectEnhancedCSSDeferred() {
            guard let webView = webView else { return }
            
            // 延迟 100ms 后注入，确保基础内容已完全渲染
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak webView] in
                guard let webView = webView else { return }
                
                if let cssScript = StreamdownWebViewPool.shared.getDeferredCSSScript() {
                    webView.evaluateJavaScript(cssScript) { _, error in
                        if let error = error {
                            print("[StreamdownWebView] Failed to inject enhanced CSS: \(error)")
                        } else {
                            // CSS 注入后可能改变高度，重新获取
                            self?.requestHeight(webView: webView)
                        }
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error)")
            notifyContentReady()
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView provisional navigation failed: \(error)")
            notifyContentReady()
        }
    }
}

#Preview {
    StreamdownWebView(
        markdown: """
        # Hello Streamdown
        
        This is a **bold** text and this is *italic*.
        
        ## Code Example
        
        ```swift
        let greeting = "Hello, World!"
        print(greeting)
        ```
        
        | Feature | Status |
        |---------|--------|
        | Tables | Working |
        | Code | Working |
        
        - Item 1
        - Item 2
        - Item 3
        """,
        isAnimating: false
    )
}
