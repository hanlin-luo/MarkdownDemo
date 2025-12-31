//
//  StreamdownWebViewPool.swift
//  MarkdownDemo
//
//  WebView 预热池 - 提前加载 WebView 以消除首次显示延迟
//

import WebKit

/// WebView 预热池，管理预加载的 WebView 实例
final class StreamdownWebViewPool {
    
    static let shared = StreamdownWebViewPool()
    
    private var availableWebViews: [WKWebView] = []
    private var isWarmedUp = false
    private var isWarming = false
    private let poolSize = 2
    private let queue = DispatchQueue(label: "com.streamdown.webviewpool", qos: .userInitiated)
    
    // 共享的 WKProcessPool 让多个 WebView 共享进程
    private let processPool = WKProcessPool()
    
    // 缓存的资源（只读取一次）
    private var cachedJS: String?
    private var cachedCSS: String?
    private var cachedBaseURL: URL?
    private var cachedHTMLTemplate: String?
    
    private init() {
        // 立即在后台加载资源缓存
        loadResourcesAsync()
    }
    
    // MARK: - Public API
    
    /// 预热 WebView 池（应在 App 启动时调用）
    func warmUp() {
        guard !isWarming && !isWarmedUp else { return }
        isWarming = true
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 确保资源已缓存
            self.ensureResourcesCached()
            
            // 在主线程创建 WebView
            DispatchQueue.main.async {
                let startTime = CFAbsoluteTimeGetCurrent()
                
                for _ in 0..<self.poolSize {
                    let webView = self.createPrewarmedWebView()
                    self.availableWebViews.append(webView)
                }
                
                self.isWarmedUp = true
                self.isWarming = false
                
                let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                print("[StreamdownPool] Warmed up \(self.poolSize) WebViews in \(String(format: "%.1f", elapsed))ms")
            }
        }
    }
    
    /// 获取一个预热的 WebView（如果可用）
    func dequeue() -> WKWebView? {
        var webView: WKWebView?
        
        if Thread.isMainThread {
            webView = availableWebViews.isEmpty ? nil : availableWebViews.removeFirst()
        } else {
            DispatchQueue.main.sync {
                webView = availableWebViews.isEmpty ? nil : availableWebViews.removeFirst()
            }
        }
        
        // 异步补充池
        if availableWebViews.count < poolSize {
            replenishPool()
        }
        
        return webView
    }
    
    /// 回收 WebView（可选，用于复用）
    func recycle(_ webView: WKWebView) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            webView.stopLoading()
            
            if self.availableWebViews.count < self.poolSize {
                if let html = self.cachedHTMLTemplate {
                    webView.loadHTMLString(html, baseURL: self.cachedBaseURL)
                    self.availableWebViews.append(webView)
                }
            }
        }
    }
    
    /// 获取共享的配置
    func createConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = processPool
        configuration.allowsInlineMediaPlayback = true
        return configuration
    }
    
    /// 获取缓存的 Base URL
    func getBaseURL() -> URL? {
        return cachedBaseURL
    }
    
    /// 获取缓存的 JS（供 StreamdownWebView 使用，避免重复读取文件）
    func getCachedJS() -> String? {
        ensureResourcesCached()
        return cachedJS
    }
    
    /// 获取缓存的 CSS
    func getCachedCSS() -> String? {
        ensureResourcesCached()
        return cachedCSS
    }
    
    // MARK: - Private
    
    private func loadResourcesAsync() {
        queue.async { [weak self] in
            self?.ensureResourcesCached()
        }
    }
    
    private func ensureResourcesCached() {
        if cachedJS == nil {
            cachedJS = loadBundledJS()
        }
        if cachedCSS == nil {
            cachedCSS = loadBundledCSS()
        }
        if cachedBaseURL == nil {
            if let resourcePath = Bundle.main.path(forResource: "streamdown-bundle", ofType: "js", inDirectory: "StreamdownBundle") {
                cachedBaseURL = URL(fileURLWithPath: resourcePath).deletingLastPathComponent()
            }
        }
        if cachedHTMLTemplate == nil {
            cachedHTMLTemplate = generateEmptyHTML()
        }
    }
    
    private func createPrewarmedWebView() -> WKWebView {
        let configuration = createConfiguration()
        
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 600), configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        ensureResourcesCached()
        
        if let html = cachedHTMLTemplate {
            webView.loadHTMLString(html, baseURL: cachedBaseURL)
        }
        
        return webView
    }
    
    private func replenishPool() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.ensureResourcesCached()
            
            DispatchQueue.main.async {
                while self.availableWebViews.count < self.poolSize {
                    let webView = self.createPrewarmedWebView()
                    self.availableWebViews.append(webView)
                }
            }
        }
    }
    
    // 标记是否使用轻量版本（不需要外部 CSS）
    private var isUsingVanillaBundle = false
    
    private func loadBundledJS() -> String? {
        // 优先使用 vanilla 版本（40KB，纯 JS，最快）
        if let path = Bundle.main.path(forResource: "streamdown-vanilla", ofType: "js", inDirectory: "StreamdownBundle"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            print("[StreamdownPool] Using vanilla bundle (40KB)")
            isUsingVanillaBundle = true
            return content
        }
        if let path = Bundle.main.path(forResource: "streamdown-vanilla", ofType: "js"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            print("[StreamdownPool] Using vanilla bundle (40KB)")
            isUsingVanillaBundle = true
            return content
        }
        // 回退到 lite 版本（179KB，React + marked）
        if let path = Bundle.main.path(forResource: "streamdown-lite", ofType: "js", inDirectory: "StreamdownBundle"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            print("[StreamdownPool] Using lite bundle (179KB)")
            isUsingVanillaBundle = true
            return content
        }
        if let path = Bundle.main.path(forResource: "streamdown-lite", ofType: "js"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            print("[StreamdownPool] Using lite bundle (179KB)")
            isUsingVanillaBundle = true
            return content
        }
        // 回退到完整版本（12MB）
        if let path = Bundle.main.path(forResource: "streamdown-bundle", ofType: "js", inDirectory: "StreamdownBundle"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            print("[StreamdownPool] Using full bundle (12MB)")
            isUsingVanillaBundle = false
            return content
        }
        if let path = Bundle.main.path(forResource: "streamdown-bundle", ofType: "js"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            print("[StreamdownPool] Using full bundle (12MB)")
            isUsingVanillaBundle = false
            return content
        }
        return nil
    }
    
    private func loadBundledCSS() -> String? {
        // vanilla/lite 版本使用内联 CSS，不需要加载 1.4MB 的外部 CSS
        if isUsingVanillaBundle {
            return nil
        }
        if let path = Bundle.main.path(forResource: "streamdown-bundle", ofType: "css", inDirectory: "StreamdownBundle"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            return content
        }
        if let path = Bundle.main.path(forResource: "streamdown-bundle", ofType: "css"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            return content
        }
        return nil
    }
    
    private func generateEmptyHTML() -> String {
        let jsTag: String
        let cssTag: String
        
        if let js = cachedJS {
            jsTag = "<script>\(js)</script>"
        } else {
            jsTag = "<script src=\"streamdown-bundle.js\"></script>"
        }
        
        if let css = cachedCSS {
            cssTag = "<style>\(css)</style>"
        } else {
            cssTag = "<link rel=\"stylesheet\" href=\"streamdown-bundle.css\">"
        }
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>Streamdown</title>
            \(cssTag)
            <style>
                * { -webkit-tap-highlight-color: transparent; box-sizing: border-box; }
                :root { color-scheme: light dark; }
                html, body { margin: 0; padding: 0; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    padding: 16px;
                    background: transparent;
                    color: #1a1a1a;
                    line-height: 1.6;
                }
                @media (prefers-color-scheme: dark) { body { color: #e5e5e5; } }
                #root { min-height: 50px; }
                #root h1 { font-size: 1.8em; font-weight: 700; margin: 0.5em 0; border-bottom: 1px solid #e5e5e5; padding-bottom: 0.3em; }
                @media (prefers-color-scheme: dark) { #root h1 { border-bottom-color: #333; } }
                #root h2 { font-size: 1.4em; font-weight: 600; margin: 0.7em 0; border-bottom: 1px solid #e5e5e5; padding-bottom: 0.3em; }
                @media (prefers-color-scheme: dark) { #root h2 { border-bottom-color: #333; } }
                #root h3 { font-size: 1.2em; font-weight: 600; margin: 0.8em 0; }
                #root p { margin: 0.8em 0; }
                #root code { background: #f4f4f4; padding: 0.2em 0.4em; border-radius: 4px; font-family: 'SF Mono', Menlo, Monaco, monospace; font-size: 0.85em; }
                @media (prefers-color-scheme: dark) { #root code { background: #2d2d2d; } }
                #root pre { background: #f4f4f4; padding: 12px; border-radius: 8px; overflow-x: auto; margin: 0.8em 0; font-size: 0.85em; }
                @media (prefers-color-scheme: dark) { #root pre { background: #1e1e1e; } }
                #root pre code { background: transparent; padding: 0; }
                #root ul, #root ol { padding-left: 1.5em; margin: 0.8em 0; }
                #root li { margin: 0.3em 0; }
                #root blockquote { border-left: 4px solid #ddd; margin: 0.8em 0; padding-left: 1em; color: #666; }
                @media (prefers-color-scheme: dark) { #root blockquote { border-left-color: #444; color: #aaa; } }
                #root table { border-collapse: collapse; width: 100%; margin: 0.8em 0; font-size: 0.9em; display: block; overflow-x: auto; }
                #root th, #root td { border: 1px solid #ddd; padding: 8px 12px; text-align: left; }
                @media (prefers-color-scheme: dark) { #root th, #root td { border-color: #444; } }
                #root th { background: #f4f4f4; font-weight: 600; }
                @media (prefers-color-scheme: dark) { #root th { background: #2d2d2d; } }
                #root a { color: #0066cc; text-decoration: none; }
                @media (prefers-color-scheme: dark) { #root a { color: #58a6ff; } }
                #root img { max-width: 100%; height: auto; border-radius: 8px; }
                #root hr { border: none; border-top: 1px solid #e5e5e5; margin: 1.5em 0; }
                @media (prefers-color-scheme: dark) { #root hr { border-top-color: #333; } }
                #root strong { font-weight: 600; }
                #root em { font-style: italic; }
                #root del { text-decoration: line-through; color: #999; }
            </style>
        </head>
        <body>
            <div id="root"></div>
            <script>window.setInitialMarkdown && window.setInitialMarkdown('', false);</script>
            \(jsTag)
            <script>if (!window.pageReady && typeof window.initStreamdown === 'function') { window.initStreamdown(); }</script>
        </body>
        </html>
        """
    }
}
