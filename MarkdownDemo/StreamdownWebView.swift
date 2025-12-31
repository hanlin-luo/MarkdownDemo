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
    var bundleType: StreamdownBundleType = .vanilla
    var enableScroll: Bool = true
    @Binding var contentHeight: CGFloat
    @Binding var isReady: Bool
    
    enum StreamdownTheme: String {
        case light = "light"
        case dark = "dark"
        case auto = "auto"
    }
    
    // 独立模式（启用滚动）
    init(markdown: String, isAnimating: Bool = false, theme: StreamdownTheme = .auto, bundleType: StreamdownBundleType = .vanilla) {
        self.markdown = markdown
        self.isAnimating = isAnimating
        self.theme = theme
        self.bundleType = bundleType
        self.enableScroll = true
        self._contentHeight = .constant(0)
        self._isReady = .constant(false)
    }
    
    // 嵌入模式（禁用滚动，提供高度绑定）
    init(markdown: String, isAnimating: Bool = false, theme: StreamdownTheme = .auto, bundleType: StreamdownBundleType = .vanilla, contentHeight: Binding<CGFloat>) {
        self.markdown = markdown
        self.isAnimating = isAnimating
        self.theme = theme
        self.bundleType = bundleType
        self.enableScroll = false
        self._contentHeight = contentHeight
        self._isReady = .constant(false)
    }
    
    // 完整模式
    init(markdown: String, isAnimating: Bool = false, theme: StreamdownTheme = .auto, bundleType: StreamdownBundleType = .vanilla, contentHeight: Binding<CGFloat>, isReady: Binding<Bool>) {
        self.markdown = markdown
        self.isAnimating = isAnimating
        self.theme = theme
        self.bundleType = bundleType
        self.enableScroll = false
        self._contentHeight = contentHeight
        self._isReady = isReady
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let bundleManager = StreamdownBundleManager.shared
        
        // 尝试获取预热的 WebView
        if let prewarmedWebView = bundleManager.dequeuePrewarmedWebView(for: bundleType) {
            // 配置预热的 WebView
            setupWebView(prewarmedWebView, context: context)
            context.coordinator.webView = prewarmedWebView
            context.coordinator.isPageReady = true  // 预热的 WebView 已经加载好 JS
            context.coordinator.pendingMarkdown = markdown
            context.coordinator.pendingIsAnimating = isAnimating
            
            // 立即更新内容
            let escapedMarkdown = escapeForJS(markdown)
            let script = "if(typeof window.updateMarkdown === 'function') { window.updateMarkdown(`\(escapedMarkdown)`, \(isAnimating)); }"
            prewarmedWebView.evaluateJavaScript(script) { _, _ in
                // 请求高度更新
                context.coordinator.requestHeight(webView: prewarmedWebView)
            }
            
            return prewarmedWebView
        }
        
        // 没有预热的 WebView，创建新的
        return createNewWebView(context: context)
    }
    
    private func setupWebView(_ webView: WKWebView, context: Context) {
        // 添加 message handlers
        let contentController = webView.configuration.userContentController
        contentController.add(context.coordinator, name: "heightChanged")
        contentController.add(context.coordinator, name: "contentReady")
        
        webView.scrollView.isScrollEnabled = enableScroll
        webView.navigationDelegate = context.coordinator
    }
    
    private func createNewWebView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let contentController = configuration.userContentController
        contentController.add(context.coordinator, name: "heightChanged")
        contentController.add(context.coordinator, name: "contentReady")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = enableScroll
        webView.navigationDelegate = context.coordinator
        
        context.coordinator.webView = webView
        context.coordinator.pendingMarkdown = markdown
        context.coordinator.pendingIsAnimating = isAnimating
        context.coordinator.bundleType = bundleType
        
        // 加载 HTML
        let bundleManager = StreamdownBundleManager.shared
        let html = bundleManager.generateHTML(
            for: bundleType,
            initialMarkdown: markdown,
            isAnimating: isAnimating,
            enableScroll: enableScroll
        )
        webView.loadHTMLString(html, baseURL: bundleManager.getBaseURL())
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.isPageReady else {
            context.coordinator.pendingMarkdown = markdown
            context.coordinator.pendingIsAnimating = isAnimating
            return
        }
        
        let escapedMarkdown = escapeForJS(markdown)
        let script = "if(typeof window.updateMarkdown === 'function') { window.updateMarkdown(`\(escapedMarkdown)`, \(isAnimating)); }"
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("JavaScript error: \(error)")
            }
        }
    }
    
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        let contentController = webView.configuration.userContentController
        contentController.removeScriptMessageHandler(forName: "heightChanged")
        contentController.removeScriptMessageHandler(forName: "contentReady")
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
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var isPageReady = false
        var pendingMarkdown: String?
        var pendingIsAnimating: Bool = false
        var bundleType: StreamdownBundleType = .vanilla
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
            requestHeightWithRetry(webView: webView, attempts: 0, lastHeight: 0)
        }
        
        private func requestHeightWithRetry(webView: WKWebView, attempts: Int, lastHeight: CGFloat) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                guard let self = self else { return }
                
                if let height = result as? CGFloat, height > 0 {
                    DispatchQueue.main.async {
                        self.heightBinding.wrappedValue = height
                    }
                    
                    if attempts < 5 && (attempts < 2 || abs(height - lastHeight) > 1) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.requestHeightWithRetry(webView: webView, attempts: attempts + 1, lastHeight: height)
                        }
                    } else {
                        self.notifyContentReady()
                    }
                } else {
                    self.notifyContentReady()
                }
            }
        }
        
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
                    
                    if attempts < 5 && (attempts < 2 || abs(height - lastHeight) > 1) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.requestHeightOnly(webView: webView, attempts: attempts + 1, lastHeight: height)
                        }
                    } else {
                        self.notifyContentReady()
                    }
                } else {
                    self.notifyContentReady()
                }
            }
        }
        
        private func notifyContentReady() {
            DispatchQueue.main.async {
                self.isReadyBinding.wrappedValue = true
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
        """,
        isAnimating: false
    )
}
