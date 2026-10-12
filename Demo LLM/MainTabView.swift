//
//  MainTabView.swift
//  Demo LLM
//

import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem {
                    Label("LLM Chat", systemImage: "sparkles")
                }
                .tag(0)

            NLPDemoView()
                .tabItem {
                    Label("NLP Studio", systemImage: "waveform.and.magnifyingglass")
                }
                .tag(1)

            MCPDemoView()
                .tabItem {
                    Label("MCP Studio", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .tag(2)
        }
    }
}

#Preview {
    MainTabView()
}
