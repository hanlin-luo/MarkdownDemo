# AGENTS.md - Coding Agent Guidelines

This document provides guidelines for AI coding agents working in the MarkdownDemo repository.

## Project Overview

**Type:** iOS/iPadOS SwiftUI application with embedded WKWebView for Markdown rendering  
**Purpose:** Demo app showcasing Streamdown (streaming Markdown renderer) integration

### Directory Structure
```
MarkdownDemo/
├── MarkdownDemo/                 # iOS app source (Swift)
│   ├── Resources/StreamdownBundle/  # Bundled JS/CSS
│   └── *.swift                   # SwiftUI views and utilities
├── MarkdownDemo.xcodeproj/       # Xcode project
└── streamdown-web/               # JavaScript source (esbuild)
    └── src/                      # JSX/JS source files
```

---

## Build Commands

### iOS App (Xcode)
```bash
# Build for simulator
xcodebuild -project MarkdownDemo.xcodeproj -scheme MarkdownDemo -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build for device (requires signing)
xcodebuild -project MarkdownDemo.xcodeproj -scheme MarkdownDemo -destination 'generic/platform=iOS' build
```

### JavaScript Bundles
```bash
cd streamdown-web

# Install dependencies
npm install

# Build vanilla bundle (PREFERRED - 168KB, with syntax highlighting)
npm run build:vanilla

# Build lite bundle (179KB, React + marked)
npm run build:lite

# Build full bundle (12MB, all features)
npm run build

# Build with sourcemaps (development)
npm run build:dev

# After building, copy to iOS resources:
cp dist/streamdown-vanilla.js ../MarkdownDemo/Resources/StreamdownBundle/
```

### Testing
No automated tests exist in this project. Manual testing via Xcode simulator.

---

## Code Style Guidelines

### Swift

#### File Header
```swift
//
//  FileName.swift
//  MarkdownDemo
//
//  Created by [author] on [date].
//

import SwiftUI
import WebKit  // Additional frameworks after SwiftUI
```

#### Naming Conventions
| Element | Convention | Example |
|---------|------------|---------|
| Types/Protocols | PascalCase | `StreamdownWebView`, `StreamdownTheme` |
| Properties/Variables | camelCase | `contentHeight`, `isAnimating` |
| Functions/Methods | camelCase | `sendHeightToSwift()`, `updateMarkdown()` |
| Enum cases | camelCase | `.light`, `.dark`, `.auto` |
| Constants | camelCase | `let poolSize = 2` |

#### SwiftUI Patterns
```swift
/// Documentation comment for public types
struct MyView: View {
    // MARK: - Properties
    @State private var isLoading = false
    @Binding var contentHeight: CGFloat
    
    // MARK: - Body
    var body: some View {
        // Use trailing closure syntax
        VStack {
            // Content
        }
    }
}

#Preview {
    MyView(contentHeight: .constant(100))
}
```

#### Error Handling
```swift
// Prefer guard let for early exits
guard let webView = webView else { return }

// Use if let for conditional unwrapping
if let height = result as? CGFloat {
    self.heightBinding.wrappedValue = height
}

// Use try? for optional error handling
let content = try? String(contentsOfFile: path, encoding: .utf8)

// Log errors with print() 
print("[StreamdownWebView] Error: \(error)")
```

#### Access Control
```swift
// Use final class for singletons
final class StreamdownWebViewPool {
    static let shared = StreamdownWebViewPool()
    private init() { }
    
    // Use private for implementation details
    private var cachedJS: String?
}
```

#### Concurrency
```swift
// Use DispatchQueue for UI updates
DispatchQueue.main.async {
    self.contentHeight = newHeight
}

// Use Task for async operations
Task {
    await someAsyncOperation()
}
```

### JavaScript

#### Module Pattern
```javascript
// ES6 imports at top
import { marked } from 'marked';
import hljs from 'highlight.js/lib/core';

// Module-level state
let currentMarkdown = '';
let rootElement = null;

// Functions use camelCase
function sendHeightToSwift(height) {
    if (window.webkit?.messageHandlers?.heightChanged) {
        window.webkit.messageHandlers.heightChanged.postMessage({ height });
    }
}
```

#### Swift-JavaScript Bridge
```javascript
// Expose functions to Swift on window object
window.updateMarkdown = function(markdown, isAnimating) {
    currentMarkdown = markdown;
    render();
};

window.setInitialMarkdown = function(markdown, isAnimating) {
    currentMarkdown = markdown;
};

window.getContentHeight = function() {
    return document.body.scrollHeight;
};

// Use optional chaining for WebKit handlers
window.webkit?.messageHandlers?.contentReady?.postMessage({});
```

#### DOM Observers
```javascript
// Use ResizeObserver for size changes
const resizeObserver = new ResizeObserver(() => {
    sendHeightToSwift(document.body.scrollHeight);
});

// Use requestAnimationFrame for debouncing
requestAnimationFrame(() => {
    sendHeightToSwift(document.body.scrollHeight);
});
```

---

## Architecture Notes

### WebView Pool Pattern
- `StreamdownWebViewPool` pre-warms WebViews at app launch
- Shared `WKProcessPool` reduces memory usage
- JS/CSS resources are cached to avoid repeated file I/O

### Bundle Priority
1. **vanilla** (168KB) - Pure JS + marked + highlight.js (PREFERRED)
2. **lite** (179KB) - React + marked  
3. **full** (12MB) - Complete streamdown with Shiki, Mermaid, KaTeX

### Coordinator Pattern
Used in `StreamdownWebView` for WKWebView delegate handling:
- Bridges SwiftUI `@Binding` to imperative WebView operations
- Handles `WKScriptMessageHandler` for height updates

---

## Important Files

| File | Purpose |
|------|---------|
| `MarkdownDemoApp.swift` | App entry, pool warmup |
| `StreamdownWebView.swift` | WKWebView wrapper |
| `StreamdownWebViewPool.swift` | WebView prewarming |
| `streamdown-web/src/index-vanilla.js` | Preferred JS bundle |

---

## Comments Style

This codebase uses bilingual comments (Chinese and English). Maintain consistency:
```swift
// 延迟注入增强 CSS（内容已显示，此时加载不会阻塞渲染）
// Deferred CSS injection (content already visible, won't block render)
```

## Code Search

Use ast-grep for structural code search:
```bash
# Swift patterns
ast-grep --lang swift -p 'struct $NAME: View { $$$ }'

# JavaScript patterns  
ast-grep --lang javascript -p 'window.$FUNC = function($$$) { $$$ }'
```
