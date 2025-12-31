//
//  CodeBlocksDemoView.swift
//  MarkdownDemo
//
//  Created by lmc on 12/31/25.
//

import SwiftUI

/// 代码块语法高亮演示
struct CodeBlocksDemoView: View {
    private let markdown = """
    # Code Blocks Demo
    
    Streamdown provides beautiful code blocks with **syntax highlighting** powered by [Shiki](https://shiki.style/).
    
    ## Swift
    
    ```swift
    import SwiftUI
    
    struct ContentView: View {
        @State private var count = 0
        
        var body: some View {
            VStack {
                Text("Count: \\(count)")
                    .font(.largeTitle)
                
                Button("Increment") {
                    count += 1
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    ```
    
    ## TypeScript
    
    ```typescript
    interface User {
        id: number;
        name: string;
        email: string;
        createdAt: Date;
    }
    
    async function fetchUser(id: number): Promise<User> {
        const response = await fetch(`/api/users/${id}`);
        if (!response.ok) {
            throw new Error('User not found');
        }
        return response.json();
    }
    ```
    
    ## Python
    
    ```python
    from dataclasses import dataclass
    from typing import List, Optional
    
    @dataclass
    class Message:
        role: str
        content: str
        
    def stream_response(
        messages: List[Message],
        model: str = "gpt-4"
    ) -> Generator[str, None, None]:
        \"\"\"Stream AI response token by token.\"\"\"
        client = OpenAI()
        stream = client.chat.completions.create(
            model=model,
            messages=[{"role": m.role, "content": m.content} for m in messages],
            stream=True
        )
        for chunk in stream:
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content
    ```
    
    ## Rust
    
    ```rust
    use std::collections::HashMap;
    
    #[derive(Debug, Clone)]
    struct Cache<T> {
        data: HashMap<String, T>,
        capacity: usize,
    }
    
    impl<T: Clone> Cache<T> {
        fn new(capacity: usize) -> Self {
            Self {
                data: HashMap::new(),
                capacity,
            }
        }
        
        fn get(&self, key: &str) -> Option<&T> {
            self.data.get(key)
        }
        
        fn set(&mut self, key: String, value: T) {
            if self.data.len() >= self.capacity {
                // Simple eviction: remove first key
                if let Some(first_key) = self.data.keys().next().cloned() {
                    self.data.remove(&first_key);
                }
            }
            self.data.insert(key, value);
        }
    }
    ```
    
    ## JSON
    
    ```json
    {
        "name": "streamdown",
        "version": "1.0.0",
        "description": "Streaming Markdown renderer for React",
        "features": [
            "streaming",
            "syntax-highlighting",
            "gfm-support",
            "math-rendering"
        ],
        "config": {
            "theme": ["github-light", "github-dark"],
            "parseIncompleteMarkdown": true
        }
    }
    ```
    
    ## Inline Code
    
    Use the `useState` hook to manage state in React. You can also use `useEffect` for side effects.
    
    The `Streamdown` component accepts `children` as the markdown content and `isAnimating` to indicate streaming state.
    """
    
    var body: some View {
        StreamdownWebView(
            markdown: markdown,
            isAnimating: false,
            theme: .auto
        )
        .navigationTitle("Code Blocks")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CodeBlocksDemoView()
    }
}
