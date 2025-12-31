//
//  BasicMarkdownDemoView.swift
//  MarkdownDemo
//
//  Created by lmc on 12/31/25.
//

import SwiftUI

/// 基础 Markdown 渲染演示
struct BasicMarkdownDemoView: View {
    private let markdown = """
    # Welcome to Streamdown
    
    Streamdown is a **React component library** that makes rendering streaming Markdown content seamless and beautiful.
    
    ## Features
    
    - **Streaming Support**: Handles incomplete Markdown gracefully
    - **GitHub Flavored Markdown**: Full GFM support
    - **Syntax Highlighting**: Beautiful code blocks with Shiki
    - **Math Support**: LaTeX equations with KaTeX
    - **Mermaid Diagrams**: Interactive diagrams
    
    ## Text Formatting
    
    This is **bold text**, this is *italic text*, and this is ***bold italic***.
    
    You can also use ~~strikethrough~~ text.
    
    > This is a blockquote. It can span multiple lines and contain other Markdown elements.
    
    ## Links and Images
    
    Check out [Streamdown](https://streamdown.ai) for more information.
    
    ## Lists
    
    ### Unordered List
    - First item
    - Second item
      - Nested item 1
      - Nested item 2
    - Third item
    
    ### Ordered List
    1. First step
    2. Second step
    3. Third step
    
    ### Task List
    - [x] Completed task
    - [ ] Pending task
    - [ ] Another pending task
    
    ## Tables
    
    | Feature | Status | Notes |
    |---------|--------|-------|
    | Streaming | ✅ | Full support |
    | Code Blocks | ✅ | With syntax highlighting |
    | Math | ✅ | KaTeX integration |
    | Mermaid | ✅ | Diagram support |
    
    ## Horizontal Rule
    
    ---
    
    That's the basic Markdown demo!
    """
    
    var body: some View {
        StreamdownWebView(
            markdown: markdown,
            isAnimating: false,
            theme: .auto
        )
        .navigationTitle("Basic Markdown")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        BasicMarkdownDemoView()
    }
}
