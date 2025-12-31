//
//  ContentView.swift
//  MarkdownDemo
//
//  Created by lmc on 12/31/25.
//

import SwiftUI

/// 主视图：TabView 展示不同 bundle 类型
/// Main view: TabView showing different bundle types
struct ContentView: View {
    var body: some View {
        TabView {
            BundleDemoView(bundleType: .vanilla)
                .tabItem {
                    Label("Vanilla", systemImage: "hare")
                }
            
            BundleDemoView(bundleType: .lite)
                .tabItem {
                    Label("Lite", systemImage: "leaf")
                }
            
            BundleDemoView(bundleType: .full)
                .tabItem {
                    Label("Full", systemImage: "cube.box")
                }
        }
    }
}

/// 演示行视图
/// Demo row view for navigation lists
struct DemoRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
