//
//  StreamingDemoView.swift
//  MarkdownDemo
//
//  Created by lmc on 12/31/25.
//

import SwiftUI

/// 流式渲染演示 - 模拟 AI 流式输出
struct StreamingDemoView: View {
    @State private var displayedMarkdown = ""
    @State private var isStreaming = false
    @State private var streamingTask: Task<Void, Never>?
    
    private let fullMarkdown = """
    # AI Response Streaming Demo
    
    This demonstrates how Streamdown handles **streaming content** from AI models in real-time.
    
    ## The Problem
    
    When streaming Markdown from AI, you encounter:
    
    - **Incomplete syntax**: `**This is bol` (unclosed bold)
    - **Partial code blocks**: Missing closing backticks
    - **Unterminated links**: `[Click here` without closing
    
    ## The Solution
    
    Streamdown intelligently handles these cases:
    
    1. **Parses incomplete blocks** - Automatically detects unterminated syntax
    2. **Progressive formatting** - Applies styling as content streams
    3. **Seamless transitions** - Smoothly updates from incomplete to complete
    
    ```python
    def stream_response(prompt: str):
        \"\"\"Stream AI response token by token.\"\"\"
        response = ai.generate(prompt, stream=True)
        for token in response:
            yield token
    ```
    
    ## Benefits
    
    | Feature | Traditional | Streamdown |
    |---------|------------|------------|
    | Incomplete Markdown | Broken | Handled |
    | Real-time Updates | Janky | Smooth |
    | User Experience | Poor | Excellent |
    
    > **Note**: This is a simulated streaming demo. In production, you would connect this to an actual AI API.
    
    That's the power of Streamdown!
    """
    
    var body: some View {
        VStack(spacing: 0) {
            // Control bar
            HStack {
                Button(action: startStreaming) {
                    Label("Start Streaming", systemImage: "play.fill")
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
                theme: .auto
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
        
        streamingTask = Task {
            // Simulate streaming by adding characters progressively
            var charIndex = fullMarkdown.startIndex
            
            while charIndex < fullMarkdown.endIndex {
                if Task.isCancelled { break }
                
                // Add a chunk of characters (simulating tokens)
                let chunkSize = Int.random(in: 1...5)
                let endIndex = fullMarkdown.index(charIndex, offsetBy: chunkSize, limitedBy: fullMarkdown.endIndex) ?? fullMarkdown.endIndex
                
                let chunk = String(fullMarkdown[charIndex..<endIndex])
                
                await MainActor.run {
                    displayedMarkdown += chunk
                }
                
                charIndex = endIndex
                
                // Random delay to simulate network latency
                try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000_000...50_000_000)) // 10-50ms
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

#Preview {
    NavigationStack {
        StreamingDemoView()
    }
}
