# Markdown 链接拦截设计方案

## 概述

在 `StreamdownWebView` 中拦截 Markdown 渲染后的链接点击事件，将导航控制权交给 SwiftUI 层，在 Sheet 中打开链接内容。

## 技术方案

采用 **WKNavigationDelegate 的 Navigation Policy 拦截**方案。

### 核心原理

通过实现 `webView(_:decidePolicyFor:decisionHandler:)` 方法，在 WebView 发起导航请求前进行拦截判断，对于用户点击的链接返回 `.cancel` 阻止内部导航，同时通过回调通知 SwiftUI 层处理。

---

## 实现细节

### 1. API 设计

```swift
struct StreamdownWebView: UIViewRepresentable {
    // 现有属性...

    /// 链接点击回调，返回被点击的 URL
    /// 如果设置了此回调，链接点击将被拦截，不会在 WebView 内部导航
    var onLinkTap: ((URL) -> Void)? = nil
}
```

### 2. Coordinator 扩展

```swift
class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    // 现有属性...

    /// 链接点击回调
    var onLinkTap: ((URL) -> Void)?

    // MARK: - Navigation Policy

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        let url = navigationAction.request.url

        // 1. 允许初始 HTML 加载（loadHTMLString 触发）
        if navigationAction.navigationType == .other {
            decisionHandler(.allow)
            return
        }

        // 2. 处理锚点链接（页内跳转）
        if let url = url, isAnchorLink(url, in: webView) {
            decisionHandler(.allow)
            return
        }

        // 3. 拦截用户点击的链接
        if navigationAction.navigationType == .linkActivated,
           let url = url,
           let onLinkTap = onLinkTap {
            DispatchQueue.main.async {
                onLinkTap(url)
            }
            decisionHandler(.cancel)
            return
        }

        // 4. 其他情况：允许导航（保持默认行为）
        decisionHandler(.allow)
    }

    /// 判断是否为锚点链接（同页面内的 #section 跳转）
    private func isAnchorLink(_ url: URL, in webView: WKWebView) -> Bool {
        guard let currentURL = webView.url else { return false }

        // 比较去掉 fragment 后的 URL 是否相同
        var currentComponents = URLComponents(url: currentURL, resolvingAgainstBaseURL: false)
        var newComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)

        currentComponents?.fragment = nil
        newComponents?.fragment = nil

        return currentComponents?.url == newComponents?.url && url.fragment != nil
    }
}
```

---

## 边缘情况处理

### 1. URL Scheme 分类处理

不同类型的链接应有不同的处理策略：

| Scheme | 处理方式 | 说明 |
|--------|----------|------|
| `http://`, `https://` | Sheet 中打开 | 普通网页链接 |
| `mailto:` | 系统邮件 App | 调用 `UIApplication.shared.open()` |
| `tel:` | 系统电话 | 调用 `UIApplication.shared.open()` |
| `#anchor` | 允许页内跳转 | 不拦截 |
| 自定义 scheme | 视情况处理 | 可能是 Deep Link |

**建议的处理逻辑：**

```swift
func handleURL(_ url: URL) {
    switch url.scheme?.lowercased() {
    case "http", "https":
        // 在 Sheet 中打开
        showWebSheet(url: url)

    case "mailto", "tel", "sms":
        // 交给系统处理
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }

    default:
        // 尝试让系统处理，或忽略
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
```

### 2. target="_blank" 处理

当链接包含 `target="_blank"` 属性时，WebKit 会通过不同的代理方法处理：

```swift
// 需要额外实现此方法来处理 target="_blank"
func webView(_ webView: WKWebView,
             createWebViewWith configuration: WKWebViewConfiguration,
             for navigationAction: WKNavigationAction,
             windowFeatures: WKWindowFeatures) -> WKWebView? {

    // 拦截 target="_blank" 链接
    if navigationAction.targetFrame == nil,
       let url = navigationAction.request.url,
       let onLinkTap = onLinkTap {
        DispatchQueue.main.async {
            onLinkTap(url)
        }
    }

    // 返回 nil 阻止创建新 WebView
    return nil
}
```

### 3. 长按预览（Context Menu）

iOS 13+ 支持链接长按预览，需要额外配置：

```swift
// 禁用默认的长按菜单（如果不需要）
webView.allowsLinkPreview = false

// 或者自定义长按行为
func webView(_ webView: WKWebView,
             contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
             completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {

    guard let url = elementInfo.linkURL else {
        completionHandler(nil)
        return
    }

    let config = UIContextMenuConfiguration(
        identifier: nil,
        previewProvider: {
            // 返回预览视图控制器
            return SFSafariViewController(url: url)
        },
        actionProvider: { _ in
            // 自定义菜单项
            let openAction = UIAction(title: "打开", image: UIImage(systemName: "safari")) { _ in
                self.onLinkTap?(url)
            }
            let copyAction = UIAction(title: "拷贝链接", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.url = url
            }
            return UIMenu(children: [openAction, copyAction])
        }
    )

    completionHandler(config)
}
```

### 4. 相对路径链接

由于使用 `loadHTMLString(_:baseURL:)` 加载 HTML，相对路径链接会基于 `baseURL` 解析：

```swift
// 当前实现
let baseURL = StreamdownBundleManager.shared.getBaseURL()
webView.loadHTMLString(html, baseURL: baseURL)
```

**注意事项：**
- Markdown 中的相对链接 `[text](./page.html)` 会解析为 `file:///.../page.html`
- 这类本地文件链接可能需要特殊处理或忽略

```swift
// 过滤本地文件链接
if url.isFileURL {
    // 可能是错误的相对路径，忽略或提示用户
    return
}
```

### 5. JavaScript 触发的导航

某些情况下，JavaScript 代码可能触发导航：

```javascript
// 这些都会触发导航
window.location.href = 'https://example.com';
window.open('https://example.com');
```

- `window.location` 变更：`navigationType` 为 `.other`，需要检查 URL 变化
- `window.open()`：通过 `createWebViewWith` 代理方法处理

### 6. 线程安全

`decidePolicyFor` 回调可能在任意线程调用：

```swift
// 确保 UI 更新在主线程
DispatchQueue.main.async {
    onLinkTap(url)
}
```

### 7. 内存管理

防止闭包造成循环引用：

```swift
// 在 Coordinator 中使用 weak self
var onLinkTap: ((URL) -> Void)? {
    didSet {
        // 闭包内部应避免强引用 Coordinator
    }
}

// 调用侧避免强引用
StreamdownWebView(
    markdown: content,
    onLinkTap: { [weak self] url in
        self?.handleLink(url)
    }
)
```

---

## SwiftUI 集成示例

### 基础用法

```swift
struct MarkdownContentView: View {
    let markdown: String

    @State private var showLinkSheet = false
    @State private var selectedURL: URL?

    var body: some View {
        StreamdownWebView(
            markdown: markdown,
            onLinkTap: { url in
                handleURL(url)
            }
        )
        .sheet(isPresented: $showLinkSheet) {
            if let url = selectedURL {
                SafariView(url: url)
            }
        }
    }

    private func handleURL(_ url: URL) {
        switch url.scheme?.lowercased() {
        case "http", "https":
            selectedURL = url
            showLinkSheet = true
        case "mailto", "tel":
            UIApplication.shared.open(url)
        default:
            break
        }
    }
}
```

### SafariView 封装

```swift
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true

        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = .systemBlue
        return safari
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
```

### 自定义 WebView Sheet（更多控制）

```swift
struct WebViewSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WebViewWrapper(url: url)
                .navigationTitle(url.host ?? "网页")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: url)
                    }
                }
        }
    }
}
```

---

## 测试用例

### 应覆盖的场景

| 场景 | 预期行为 |
|------|----------|
| 点击 `https://` 链接 | Sheet 打开 |
| 点击 `mailto:` 链接 | 打开邮件 App |
| 点击 `tel:` 链接 | 打开电话 |
| 点击 `#section` 锚点 | 页内滚动，不弹 Sheet |
| 点击 `target="_blank"` 链接 | Sheet 打开 |
| 长按链接 | 显示预览/菜单 |
| 快速连续点击 | 只打开一个 Sheet |
| 点击无效 URL | 不崩溃，可选提示 |

### 测试 Markdown

```markdown
## 链接测试

- [普通链接](https://www.apple.com)
- [新窗口链接](https://www.google.com){:target="_blank"}
- [邮件链接](mailto:test@example.com)
- [电话链接](tel:+8612345678900)
- [锚点链接](#section1)
- [相对路径](./page.html)

## Section1 {#section1}

这是锚点目标位置。
```

---

## 兼容性

| 特性 | 最低版本 |
|------|----------|
| WKNavigationDelegate | iOS 8.0+ |
| SFSafariViewController | iOS 9.0+ |
| Context Menu | iOS 13.0+ |
| SwiftUI Sheet | iOS 13.0+ |

---

## 实现清单

- [ ] 在 `StreamdownWebView` 添加 `onLinkTap` 属性
- [ ] 在 `Coordinator` 添加 `onLinkTap` 属性并传递
- [ ] 实现 `decidePolicyFor` 方法
- [ ] 实现 `createWebViewWith` 方法（处理 target="_blank"）
- [ ] 添加 URL scheme 分类处理
- [ ] 添加锚点链接判断逻辑
- [ ] 创建 `SafariView` 封装
- [ ] 更新各 Demo View 的调用方式
- [ ] 添加测试用例
