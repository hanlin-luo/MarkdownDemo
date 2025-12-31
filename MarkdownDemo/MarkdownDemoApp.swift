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
        // 预热 WebView 池，消除首次显示延迟
        StreamdownWebViewPool.shared.warmUp()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
