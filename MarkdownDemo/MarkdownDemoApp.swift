//
//  MarkdownDemoApp.swift
//  MarkdownDemo
//
//  Created by lmc on 12/31/25.
//

import SwiftUI

@main
struct MarkdownDemoApp: App {
    
    init() {
        // 预热 vanilla bundle 的 WebView（最常用，启动时立即预热）
        // Warm up vanilla bundle WebViews (most commonly used)
        StreamdownBundleManager.shared.warmUp(.vanilla)
        
        // 预加载其他 bundle 的资源（只加载 JS/CSS，不创建 WebView）
        // Preload other bundle resources (JS/CSS only, no WebView creation)
        StreamdownBundleManager.shared.preloadAll()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
