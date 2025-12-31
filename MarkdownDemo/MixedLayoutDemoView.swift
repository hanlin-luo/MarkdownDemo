//
//  MixedLayoutDemoView.swift
//  MarkdownDemo
//
//  Created by lmc on 12/31/25.
//

import SwiftUI

/// 混合布局演示 - Markdown 作为子视图与原生 SwiftUI 组件结合
struct MixedLayoutDemoView: View {
    @State private var showShareSheet = false
    @State private var webViewHeight: CGFloat = 100
    
    private let markdownContent = """
# AI 助手回复

您好！我已经分析了您的问题，以下是我的建议：

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

> **提示**: 建议使用 Instruments 进行详细的性能分析。

## 更多建议

在开发过程中，还需要注意以下几点：

- 避免在 `body` 中进行复杂计算
- 使用 `@ViewBuilder` 提取子视图
- 合理使用 `EquatableView` 减少不必要的更新
- 对于大列表，考虑使用 `LazyVStack` 或 `LazyHStack`

### 推荐阅读

1. [SwiftUI Performance Tips](https://developer.apple.com)
2. [WWDC Sessions on SwiftUI](https://developer.apple.com/wwdc)
3. [Swift Performance Best Practices](https://swift.org)

希望这些建议对您有帮助！如有疑问请随时询问。
"""
    
    private let tags = ["Swift", "iOS", "性能优化", "SwiftUI", "最佳实践"]
    private let folderName = "技术文档"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Markdown 内容区域 - 直接显示，不使用 opacity 控制
                StreamdownWebView(
                    markdown: markdownContent,
                    isAnimating: false,
                    theme: .auto,
                    contentHeight: $webViewHeight
                )
                .frame(height: max(webViewHeight, 100))
                
                Divider()
                    .padding(.top, 16)
                
                // 底部信息区域 - 跟随内容滚动
                VStack(spacing: 12) {
                    // 标签组
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                TagView(text: tag)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // 文件夹显示
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.orange)
                        Text(folderName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("2024/12/31")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("AI 对话记录")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { showShareSheet = true }) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {}) {
                        Label("复制内容", systemImage: "doc.on.doc")
                    }
                    
                    Button(action: {}) {
                        Label("添加到收藏", systemImage: "star")
                    }
                    
                    Divider()
                    
                    Button(action: {}) {
                        Label("导出为 PDF", systemImage: "arrow.down.doc")
                    }
                    
                    Button(action: {}) {
                        Label("导出为 Markdown", systemImage: "doc.text")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {}) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [markdownContent])
        }
    }
}

/// 标签视图
struct TagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.1))
            .foregroundStyle(.blue)
            .clipShape(Capsule())
    }
}

/// 分享面板
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        MixedLayoutDemoView()
    }
}
