//
//  StreamdownBundleManager.swift
//  MarkdownDemo
//
//  Bundle 资源管理器 - 支持加载不同版本的 JS bundle，并提供 WebView 预热
//

import Foundation
import WebKit

/// Bundle 类型枚举
enum StreamdownBundleType: String, CaseIterable, Identifiable {
    case vanilla = "vanilla"    // 168KB, 纯 JS + highlight.js
    case lite = "lite"          // 179KB, React + marked
    case full = "full"          // 12MB, 完整版 Streamdown
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .vanilla: return "Vanilla"
        case .lite: return "Lite"
        case .full: return "Full"
        }
    }
    
    var description: String {
        switch self {
        case .vanilla: return "168KB, highlight.js"
        case .lite: return "179KB, React"
        case .full: return "12MB, Shiki/KaTeX/Mermaid"
        }
    }
    
    var icon: String {
        switch self {
        case .vanilla: return "hare"
        case .lite: return "leaf"
        case .full: return "cube.box"
        }
    }
    
    var jsFileName: String {
        switch self {
        case .vanilla: return "streamdown-vanilla"
        case .lite: return "streamdown-lite"
        case .full: return "streamdown-bundle"
        }
    }
    
    var cssFileName: String? {
        switch self {
        case .full: return "streamdown-bundle"
        default: return nil
        }
    }
}

/// Bundle 资源管理器 - 支持资源缓存和 WebView 预热
final class StreamdownBundleManager {
    
    static let shared = StreamdownBundleManager()
    
    // 缓存的资源
    private var cachedJS: [StreamdownBundleType: String] = [:]
    private var cachedCSS: [StreamdownBundleType: String] = [:]
    private var cachedBaseURL: URL?
    
    // 预热的 WebView 池（按 bundle 类型分组）
    private var prewarmedWebViews: [StreamdownBundleType: [WKWebView]] = [:]
    private var isWarming: [StreamdownBundleType: Bool] = [:]
    private let poolSize = 2
    
    private let queue = DispatchQueue(label: "com.streamdown.bundlemanager", qos: .userInitiated)
    
    private init() {
        loadBaseURL()
    }
    
    // MARK: - Public API
    
    /// 预加载所有 bundle 的资源（不创建 WebView）
    func preloadAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            for bundleType in StreamdownBundleType.allCases {
                _ = self.loadJS(for: bundleType)
                if bundleType.cssFileName != nil {
                    _ = self.loadCSS(for: bundleType)
                }
            }
            print("[BundleManager] All bundles preloaded")
        }
    }
    
    /// 预热指定类型的 WebView（在 App 启动时调用）
    func warmUp(_ bundleType: StreamdownBundleType) {
        guard isWarming[bundleType] != true else { return }
        isWarming[bundleType] = true
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 确保 JS 已加载
            _ = self.loadJS(for: bundleType)
            if bundleType.cssFileName != nil {
                _ = self.loadCSS(for: bundleType)
            }
            
            // 在主线程创建预热的 WebView
            DispatchQueue.main.async {
                let startTime = CFAbsoluteTimeGetCurrent()
                
                if self.prewarmedWebViews[bundleType] == nil {
                    self.prewarmedWebViews[bundleType] = []
                }
                
                for _ in 0..<self.poolSize {
                    let webView = self.createPrewarmedWebView(for: bundleType)
                    self.prewarmedWebViews[bundleType]?.append(webView)
                }
                
                self.isWarming[bundleType] = false
                
                let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                print("[BundleManager] Warmed up \(self.poolSize) \(bundleType.displayName) WebViews in \(String(format: "%.1f", elapsed))ms")
            }
        }
    }
    
    /// 获取预热的 WebView（如果可用）
    func dequeuePrewarmedWebView(for bundleType: StreamdownBundleType) -> WKWebView? {
        guard Thread.isMainThread else {
            var result: WKWebView?
            DispatchQueue.main.sync {
                result = self.dequeuePrewarmedWebView(for: bundleType)
            }
            return result
        }
        
        guard var pool = prewarmedWebViews[bundleType], !pool.isEmpty else {
            return nil
        }
        
        let webView = pool.removeFirst()
        prewarmedWebViews[bundleType] = pool
        
        // 异步补充池
        replenishPool(for: bundleType)
        
        return webView
    }
    
    /// 获取指定类型的 JS 内容
    func getJS(for bundleType: StreamdownBundleType) -> String? {
        if let cached = cachedJS[bundleType] {
            return cached
        }
        return loadJS(for: bundleType)
    }
    
    /// 获取指定类型的 CSS 内容
    func getCSS(for bundleType: StreamdownBundleType) -> String? {
        guard bundleType.cssFileName != nil else { return nil }
        if let cached = cachedCSS[bundleType] {
            return cached
        }
        return loadCSS(for: bundleType)
    }
    
    /// 获取 base URL
    func getBaseURL() -> URL? {
        return cachedBaseURL
    }
    
    /// 检查指定 bundle 是否可用
    func isAvailable(_ bundleType: StreamdownBundleType) -> Bool {
        return getJS(for: bundleType) != nil
    }
    
    /// 生成指定 bundle 类型的 HTML
    func generateHTML(for bundleType: StreamdownBundleType, initialMarkdown: String = "", isAnimating: Bool = false, enableScroll: Bool = true, autoScrollToBottom: Bool = false) -> String {
        let overflowStyle = enableScroll ? "auto" : "hidden"
        let escapedMarkdown = escapeForJS(initialMarkdown)
        
        let bundledJS = getJS(for: bundleType)
        let jsTag: String
        if let js = bundledJS {
            jsTag = "<script>\(js)</script>"
        } else {
            jsTag = "<script src=\"\(bundleType.jsFileName).js\"></script>"
        }
        
        // 只有 full bundle 需要加载 CSS
        let cssTag: String
        if bundleType == .full, let css = getCSS(for: bundleType) {
            cssTag = "<style>\(css)</style>"
        } else {
            cssTag = ""
        }
        
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
                    overflow: \(overflowStyle);
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
            \(cssTag)
        </head>
        <body>
            <div id="root"></div>
            
            <script>
                window.setInitialMarkdown && window.setInitialMarkdown(`\(escapedMarkdown)`, \(isAnimating), \(autoScrollToBottom));
            </script>
            
            \(jsTag)
            
            <script>
                if (!window.pageReady && typeof window.initStreamdown === 'function') {
                    window.initStreamdown();
                }
            </script>
        </body>
        </html>
        """
    }
    
    // MARK: - Private
    
    private func loadBaseURL() {
        for bundleType in StreamdownBundleType.allCases {
            if let path = Bundle.main.path(forResource: bundleType.jsFileName, ofType: "js", inDirectory: "StreamdownBundle") {
                cachedBaseURL = URL(fileURLWithPath: path).deletingLastPathComponent()
                return
            }
            if let path = Bundle.main.path(forResource: bundleType.jsFileName, ofType: "js") {
                cachedBaseURL = URL(fileURLWithPath: path).deletingLastPathComponent()
                return
            }
        }
    }
    
    private func loadJS(for bundleType: StreamdownBundleType) -> String? {
        if let cached = cachedJS[bundleType] {
            return cached
        }
        
        let fileName = bundleType.jsFileName
        
        if let path = Bundle.main.path(forResource: fileName, ofType: "js", inDirectory: "StreamdownBundle"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            cachedJS[bundleType] = content
            print("[BundleManager] Loaded \(bundleType.displayName) bundle from StreamdownBundle/")
            return content
        }
        
        if let path = Bundle.main.path(forResource: fileName, ofType: "js"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            cachedJS[bundleType] = content
            print("[BundleManager] Loaded \(bundleType.displayName) bundle")
            return content
        }
        
        print("[BundleManager] Failed to load \(bundleType.displayName) bundle")
        return nil
    }
    
    private func loadCSS(for bundleType: StreamdownBundleType) -> String? {
        guard let fileName = bundleType.cssFileName else { return nil }
        
        if let cached = cachedCSS[bundleType] {
            return cached
        }
        
        if let path = Bundle.main.path(forResource: fileName, ofType: "css", inDirectory: "StreamdownBundle"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            cachedCSS[bundleType] = content
            print("[BundleManager] Loaded \(bundleType.displayName) CSS")
            return content
        }
        
        if let path = Bundle.main.path(forResource: fileName, ofType: "css"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            cachedCSS[bundleType] = content
            print("[BundleManager] Loaded \(bundleType.displayName) CSS")
            return content
        }
        
        return nil
    }
    
    private func createPrewarmedWebView(for bundleType: StreamdownBundleType) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 600), configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        // 加载空白 HTML（JS 已解析完成）
        let html = generateHTML(for: bundleType)
        webView.loadHTMLString(html, baseURL: cachedBaseURL)
        
        return webView
    }
    
    private func replenishPool(for bundleType: StreamdownBundleType) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                let currentCount = self.prewarmedWebViews[bundleType]?.count ?? 0
                guard currentCount < self.poolSize else { return }
                
                for _ in currentCount..<self.poolSize {
                    let webView = self.createPrewarmedWebView(for: bundleType)
                    if self.prewarmedWebViews[bundleType] == nil {
                        self.prewarmedWebViews[bundleType] = []
                    }
                    self.prewarmedWebViews[bundleType]?.append(webView)
                }
            }
        }
    }
    
    private func escapeForJS(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
