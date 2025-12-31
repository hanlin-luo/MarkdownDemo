# Streamdown iOS Demo

基于 WKWebView 的高性能 iOS/iPadOS Markdown 渲染方案，专为 AI 流式输出场景优化。

---

## 概述

Streamdown iOS 提供 SwiftUI 封装的 Markdown 渲染组件：

- **即时加载** - WebView 预热机制消除首次渲染延迟
- **语法高亮** - 通过 highlight.js 支持 25+ 种语言
- **混合布局** - Markdown 与原生 SwiftUI 组件无缝结合
- **流式支持** - 处理 AI 流式输出时的不完整 Markdown
- **多 Bundle 支持** - 可选择 Vanilla (168KB)、Lite (179KB) 或 Full (12MB)

## 快速开始

### 安装

1. 复制以下文件到你的项目：
   - `MarkdownDemo/StreamdownWebView.swift`
   - `MarkdownDemo/StreamdownBundleManager.swift`
2. 复制 `MarkdownDemo/Resources/StreamdownBundle/` 文件夹到你的项目
3. 将 bundle 文件夹添加到 Xcode target

### 基本用法

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        StreamdownWebView(
            markdown: "# 你好\n\n这是 **Markdown**！",
            isAnimating: false,
            theme: .auto,
            bundleType: .vanilla  // 可选：.vanilla, .lite, .full
        )
    }
}
```

### 应用初始化

在应用启动时预热 WebView，实现即时渲染：

```swift
@main
struct MyApp: App {
    init() {
        // 预热 vanilla bundle 的 WebView（最常用）
        StreamdownBundleManager.shared.warmUp(.vanilla)
        
        // 可选：预加载其他 bundle 的资源
        StreamdownBundleManager.shared.preloadAll()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

---

## Bundle 版本

| Bundle | 大小 | 语法高亮 | 流式处理 | 数学/图表 |
|--------|------|----------|----------|-----------|
| `vanilla` | 168KB | highlight.js (25+ 语言) | 基础 | - |
| `lite` | 179KB | - | 基础 | - |
| `full` | 12MB | Shiki | 完整 | KaTeX/Mermaid |

### 如何选择？

**Vanilla（推荐大多数应用）**
- 体积和功能的最佳平衡
- 支持 25+ 种语言的语法高亮
- 加载快速，适合聊天应用

**Lite（最小体积）**
- 无语法高亮
- 不需要代码块高亮时使用

**Full（功能完整）**
- 需要数学公式（`$x^2$`）或图表（```mermaid）时使用
- 真正的流式支持：自动补全未闭合的 Markdown
- 体积较大（12MB），按需使用

### 指定 Bundle 类型

```swift
// 使用 vanilla bundle（默认）
StreamdownWebView(
    markdown: content,
    bundleType: .vanilla
)

// 使用 full bundle（需要数学公式/图表）
StreamdownWebView(
    markdown: content,
    bundleType: .full
)
```

---

## 混合布局（推荐）

最强大的使用模式是**混合布局** —— 将 Markdown 嵌入原生 SwiftUI 视图中：

- 原生性能渲染 UI 外壳（标题栏、工具栏、按钮）
- 丰富的 Markdown 内容渲染
- 动态高度的正确滚动行为

### 示例：AI 聊天消息

```swift
struct ChatMessageView: View {
    let message: String
    @State private var webViewHeight: CGFloat = 100
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Markdown 内容，动态高度
                StreamdownWebView(
                    markdown: message,
                    isAnimating: false,
                    theme: .auto,
                    bundleType: .vanilla,
                    contentHeight: $webViewHeight
                )
                .frame(height: max(webViewHeight, 100))
                
                Divider()
                    .padding(.top, 16)
                
                // 下方的原生 SwiftUI 组件
                HStack {
                    Button("复制") { /* ... */ }
                    Button("分享") { /* ... */ }
                    Spacer()
                    Text("刚刚")
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }
}
```

### 要点

1. **使用 `contentHeight` 绑定** - WebView 会报告内容高度，实现正确的尺寸计算
2. **设置 `frame(height:)`** - 使用报告的高度，并设定最小值
3. **禁用内部滚动** - 使用 `contentHeight` 时，WebView 自动禁用内部滚动
4. **统一滚动** - 将 SwiftUI 组件放在同一个 `VStack` 中实现统一滚动

---

## 流式模式

对于 AI 流式输出场景，使用 `isAnimating: true`：

```swift
struct StreamingView: View {
    @State private var content = ""
    @State private var isStreaming = false
    
    var body: some View {
        StreamdownWebView(
            markdown: content,
            isAnimating: isStreaming,  // 优化频繁更新
            theme: .auto,
            bundleType: .vanilla
        )
    }
    
    func appendToken(_ token: String) {
        content += token
    }
}
```

---

## API 参考

### StreamdownWebView

```swift
// 独立模式（启用内部滚动）
StreamdownWebView(
    markdown: String,
    isAnimating: Bool = false,
    theme: StreamdownTheme = .auto,
    bundleType: StreamdownBundleType = .vanilla
)

// 嵌入模式（用于混合布局，禁用内部滚动）
StreamdownWebView(
    markdown: String,
    isAnimating: Bool = false,
    theme: StreamdownTheme = .auto,
    bundleType: StreamdownBundleType = .vanilla,
    contentHeight: Binding<CGFloat>
)

// 完整控制
StreamdownWebView(
    markdown: String,
    isAnimating: Bool = false,
    theme: StreamdownTheme = .auto,
    bundleType: StreamdownBundleType = .vanilla,
    contentHeight: Binding<CGFloat>,
    isReady: Binding<Bool>
)
```

### StreamdownTheme

```swift
enum StreamdownTheme {
    case light   // 强制浅色模式
    case dark    // 强制深色模式
    case auto    // 跟随系统（推荐）
}
```

### StreamdownBundleType

```swift
enum StreamdownBundleType {
    case vanilla  // 168KB, highlight.js
    case lite     // 179KB, React + marked
    case full     // 12MB, Shiki/KaTeX/Mermaid
}
```

### StreamdownBundleManager

```swift
// 预热指定 bundle 的 WebView（在 App 启动时调用）
StreamdownBundleManager.shared.warmUp(.vanilla)

// 预加载所有 bundle 的 JS/CSS 资源
StreamdownBundleManager.shared.preloadAll()

// 检查 bundle 是否可用
StreamdownBundleManager.shared.isAvailable(.vanilla)
```

---

## 构建 Bundle

```bash
cd streamdown-web
npm install

# 构建 vanilla（推荐）
npm run build:vanilla

# 构建 lite
npm run build:lite

# 构建 full
npm run build

# 复制到 iOS 资源目录
cp dist/streamdown-vanilla.js ../MarkdownDemo/Resources/StreamdownBundle/
cp dist/streamdown-lite.js ../MarkdownDemo/Resources/StreamdownBundle/
cp dist/streamdown-bundle.js ../MarkdownDemo/Resources/StreamdownBundle/
cp dist/streamdown-bundle.css ../MarkdownDemo/Resources/StreamdownBundle/
```

---

## 项目结构

```
MarkdownDemo/
├── MarkdownDemo/
│   ├── StreamdownWebView.swift       # WebView 封装
│   ├── StreamdownBundleManager.swift # Bundle 管理 + WebView 预热
│   ├── BundleDemoView.swift          # Demo 视图
│   ├── ContentView.swift             # TabView 主视图
│   └── Resources/StreamdownBundle/   # JS/CSS bundle 文件
└── streamdown-web/                   # JavaScript 源码
    └── src/
        ├── index-vanilla.js          # Vanilla bundle 源码
        ├── index-lite.jsx            # Lite bundle 源码
        └── index.jsx                 # Full bundle 源码
```

---

## 许可证

MIT License
