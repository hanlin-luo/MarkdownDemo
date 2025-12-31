//
//  ContentView.swift
//  MarkdownDemo
//
//  Created by lmc on 12/31/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        BasicMarkdownDemoView()
                    } label: {
                        DemoRowView(
                            icon: "doc.text",
                            iconColor: .blue,
                            title: "Basic Markdown",
                            description: "Headers, lists, tables, links, and more"
                        )
                    }
                    
                    NavigationLink {
                        StreamingDemoView()
                    } label: {
                        DemoRowView(
                            icon: "waveform",
                            iconColor: .green,
                            title: "Streaming Demo",
                            description: "Simulate AI streaming with incomplete Markdown"
                        )
                    }
                    
                    NavigationLink {
                        CodeBlocksDemoView()
                    } label: {
                        DemoRowView(
                            icon: "chevron.left.forwardslash.chevron.right",
                            iconColor: .purple,
                            title: "Code Blocks",
                            description: "Syntax highlighting for multiple languages"
                        )
                    }
                    
                    NavigationLink {
                        MixedLayoutDemoView()
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
                } footer: {
                    Text("Powered by Streamdown - a React library for streaming Markdown, integrated via WKWebView.")
                }
                
                Section {
                    Link(destination: URL(string: "https://streamdown.ai")!) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(.blue)
                            Text("Streamdown Website")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/vercel/streamdown")!) {
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .foregroundStyle(.gray)
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Resources")
                }
            }
            .navigationTitle("Streamdown Demo")
        }
    }
}

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
