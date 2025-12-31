//
//  BundleDemoView.swift
//  MarkdownDemo
//
//  通用的 Bundle 演示视图 - 展示指定 bundle 类型的所有功能
//

import SwiftUI

/// 通用的 Bundle 演示视图
struct BundleDemoView: View {
    let bundleType: StreamdownBundleType
    
    var body: some View {
        NavigationStack {
            List {
                // Bundle 信息
                Section {
                    BundleInfoRow(bundleType: bundleType)
                } header: {
                    Text("Bundle Info")
                }
                
                // 演示列表
                Section {
                    NavigationLink {
                        BasicDemoContent(bundleType: bundleType)
                    } label: {
                        DemoRowView(
                            icon: "doc.text",
                            iconColor: .blue,
                            title: "Basic Markdown",
                            description: "Headers, lists, tables, links, and more"
                        )
                    }
                    
                    NavigationLink {
                        StreamingDemoContent(bundleType: bundleType)
                    } label: {
                        DemoRowView(
                            icon: "waveform",
                            iconColor: .green,
                            title: "Streaming Demo",
                            description: "Simulate AI streaming output"
                        )
                    }
                    
                    NavigationLink {
                        CodeBlocksDemoContent(bundleType: bundleType)
                    } label: {
                        DemoRowView(
                            icon: "chevron.left.forwardslash.chevron.right",
                            iconColor: .purple,
                            title: "Code Blocks",
                            description: "Syntax highlighting for multiple languages"
                        )
                    }
                    
                    NavigationLink {
                        MixedLayoutDemoContent(bundleType: bundleType)
                    } label: {
                        DemoRowView(
                            icon: "rectangle.split.3x1",
                            iconColor: .orange,
                            title: "Mixed Layout",
                            description: "Markdown with native SwiftUI components"
                        )
                    }
                } header: {
                    Text("Demos")
                }
            }
            .navigationTitle(bundleType.displayName)
        }
    }
}

/// Bundle 信息行
struct BundleInfoRow: View {
    let bundleType: StreamdownBundleType
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: bundleType.icon)
                .font(.title)
                .foregroundStyle(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(bundleType.displayName)
                    .font(.headline)
                Text(bundleType.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 可用状态指示
            if StreamdownBundleManager.shared.isAvailable(bundleType) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Basic Demo Content

struct BasicDemoContent: View {
    let bundleType: StreamdownBundleType
    
    var body: some View {
        StreamdownWebView(
            markdown: DemoMarkdownData.basic,
            isAnimating: false,
            theme: .auto,
            bundleType: bundleType
        )
        .navigationTitle("Basic Markdown")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Streaming Demo Content

struct StreamingDemoContent: View {
    let bundleType: StreamdownBundleType
    
    @State private var displayedMarkdown = ""
    @State private var isStreaming = false
    @State private var streamingTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 0) {
            // Control bar
            HStack {
                Button(action: startStreaming) {
                    Label("Start", systemImage: "play.fill")
                }
                .disabled(isStreaming)
                
                Spacer()
                
                Button(action: resetDemo) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .disabled(isStreaming)
                
                if isStreaming {
                    ProgressView()
                        .padding(.leading, 8)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Markdown content
            StreamdownWebView(
                markdown: displayedMarkdown,
                isAnimating: isStreaming,
                theme: .auto,
                bundleType: bundleType,
                autoScrollToBottom: true
            )
        }
        .navigationTitle("Streaming Demo")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            streamingTask?.cancel()
        }
    }
    
    private func startStreaming() {
        guard !isStreaming else { return }
        
        displayedMarkdown = ""
        isStreaming = true
        let fullMarkdown = DemoMarkdownData.streaming
        
        streamingTask = Task {
            var charIndex = fullMarkdown.startIndex
            
            while charIndex < fullMarkdown.endIndex {
                if Task.isCancelled { break }
                
                let chunkSize = Int.random(in: 1...5)
                let endIndex = fullMarkdown.index(charIndex, offsetBy: chunkSize, limitedBy: fullMarkdown.endIndex) ?? fullMarkdown.endIndex
                let chunk = String(fullMarkdown[charIndex..<endIndex])
                
                await MainActor.run {
                    displayedMarkdown += chunk
                }
                
                charIndex = endIndex
                try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000_000...50_000_000))
            }
            
            await MainActor.run {
                isStreaming = false
            }
        }
    }
    
    private func resetDemo() {
        streamingTask?.cancel()
        displayedMarkdown = ""
        isStreaming = false
    }
}

// MARK: - Code Blocks Demo Content

struct CodeBlocksDemoContent: View {
    let bundleType: StreamdownBundleType
    
    var body: some View {
        StreamdownWebView(
            markdown: DemoMarkdownData.codeBlocks,
            isAnimating: false,
            theme: .auto,
            bundleType: bundleType
        )
        .navigationTitle("Code Blocks")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Mixed Layout Demo Content

struct MixedLayoutDemoContent: View {
    let bundleType: StreamdownBundleType

    @State private var webViewHeight: CGFloat = 100
    @State private var selectedURL: IdentifiableURL?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Markdown 内容区域
                StreamdownWebView(
                    markdown: DemoMarkdownData.mixedLayout,
                    isAnimating: false,
                    theme: .auto,
                    bundleType: bundleType,
                    contentHeight: $webViewHeight,
                    onLinkTap: { url in
                        handleURL(url)
                    }
                )
                .frame(height: max(webViewHeight, 100))

                Divider()
                    .padding(.top, 16)

                // 底部信息区域 - 原生 SwiftUI 组件
                VStack(spacing: 12) {
                    // 标签组
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Swift", "iOS", "SwiftUI", "Performance"], id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // 操作按钮
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)

                        Button(action: {}) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Mixed Layout")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedURL) { item in
            SafariView(url: item.url)
        }
    }

    private func handleURL(_ url: URL) {
        switch url.scheme?.lowercased() {
        case "http", "https":
            selectedURL = IdentifiableURL(url: url)
        case "mailto", "tel", "sms":
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        default:
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
}

/// URL wrapper for sheet(item:)
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Demo Markdown Data
// 所有演示使用完全相同的测试数据，以便比较不同 bundle 的渲染效果

enum DemoMarkdownData {
    
    static let basic = """
    # Welcome to Streamdown
    
    This is a **Markdown** rendering demo showcasing various formatting features.
    
    ## Text Formatting
    
    - **Bold text** for emphasis
    - *Italic text* for subtle emphasis
    - ~~Strikethrough~~ for deleted content
    - `Inline code` for technical terms
    - Links: [Streamdown](https://streamdown.ai)
    
    ## Lists
    
    ### Ordered List
    1. First item
    2. Second item
    3. Third item
    
    ### Unordered List
    - Apple
    - Banana
    - Cherry
    
    ## Blockquote
    
    > "The best way to predict the future is to invent it."
    > — Alan Kay
    
    ## Table
    
    | Feature | Vanilla | Lite | Full |
    |---------|---------|------|------|
    | Size | 168KB | 179KB | 12MB |
    | Syntax Highlighting | highlight.js | None | Shiki |
    | Math (KaTeX) | No | No | Yes |
    | Diagrams | No | No | Mermaid |
    
    ## Horizontal Rule
    
    ---
    
    That's all for the basic demo!
    """
    
    static let streaming = """
    # AI Response Streaming Demo
    
    This demonstrates how Streamdown handles **streaming content** from AI models.
    
    ## The Challenge
    
    When streaming Markdown from AI:
    
    - **Incomplete syntax**: `**This is bol` (unclosed bold)
    - **Partial code blocks**: Missing closing backticks
    - **Unterminated links**: `[Click here` without closing
    
    ## Code Example
    
    ```python
    def stream_response(prompt: str):
        \"\"\"Stream AI response token by token.\"\"\"
        response = ai.generate(prompt, stream=True)
        for token in response:
            yield token
    ```
    
    ## Performance Comparison
    
    | Feature | Traditional | Streamdown |
    |---------|------------|------------|
    | Incomplete Markdown | Broken | Handled |
    | Real-time Updates | Janky | Smooth |
    | User Experience | Poor | Excellent |
    
    > **Note**: This is a simulated streaming demo.
    
    That's the power of Streamdown!
    """
    
    static let codeBlocks = """
    # Code Syntax Highlighting
    
    Testing syntax highlighting across different programming languages.
    
    ## Swift
    
    ```swift
    struct ContentView: View {
        @State private var count = 0
        
        var body: some View {
            VStack {
                Text("Count: \\(count)")
                Button("Increment") {
                    count += 1
                }
            }
        }
    }
    ```
    
    ## Python
    
    ```python
    def fibonacci(n: int) -> int:
        \"\"\"Calculate the nth Fibonacci number.\"\"\"
        if n <= 1:
            return n
        return fibonacci(n - 1) + fibonacci(n - 2)
    
    # Print first 10 Fibonacci numbers
    for i in range(10):
        print(f"F({i}) = {fibonacci(i)}")
    ```
    
    ## JavaScript
    
    ```javascript
    async function fetchData(url) {
        try {
            const response = await fetch(url);
            const data = await response.json();
            return data;
        } catch (error) {
            console.error('Fetch error:', error);
            throw error;
        }
    }
    ```
    
    ## TypeScript
    
    ```typescript
    interface User {
        id: number;
        name: string;
        email: string;
    }
    
    async function getUser(id: number): Promise<User> {
        const response = await fetch(`/api/users/${id}`);
        return response.json();
    }
    ```
    
    ## JSON
    
    ```json
    {
        "name": "Streamdown",
        "version": "1.0.0",
        "features": ["streaming", "highlighting", "tables"],
        "bundles": {
            "vanilla": "168KB",
            "lite": "179KB",
            "full": "12MB"
        }
    }
    ```
    
    ## Bash
    
    ```bash
    #!/bin/bash
    
    # Build all bundles
    cd streamdown-web
    npm install
    npm run build:vanilla
    npm run build:lite
    npm run build
    
    echo "Build complete!"
    ```
    """
    
    static let mixedLayout = """
    # AI 助手回复

    您好！这是混合布局演示，展示 Markdown 内容与原生 SwiftUI 组件的结合。更多信息请访问 [Streamdown](https://streamdown.ai)。

    ## 核心要点
    
    1. **性能优化** - 减少不必要的渲染
    2. **代码复用** - 抽取公共组件
    3. **状态管理** - 使用合适的状态容器
    
    ## 代码示例
    
    ```swift
    struct ContentView: View {
        @StateObject private var viewModel = ViewModel()
        
        var body: some View {
            List(viewModel.items) { item in
                ItemRow(item: item)
            }
        }
    }
    ```
    
    ## 性能对比
    
    | 方案 | 渲染时间 | 内存占用 |
    |------|---------|---------|
    | 优化前 | 120ms | 45MB |
    | 优化后 | 35ms | 28MB |
    
    > **提示**: 下方的标签和按钮是原生 SwiftUI 组件，与 WebView 混合布局。点击上方链接可在 Sheet 中打开。
    """
}

#Preview {
    BundleDemoView(bundleType: .vanilla)
}
