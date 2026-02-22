//
//  ContentView.swift
//  Yogik
//
//  Created by Manbhawan on 08/01/2026.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("selectedTab") private var selectedTab = 0
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @State private var showingHelp = false

    var body: some View {
        TabView(selection: $selectedTab) {
            YogaView()
                .tabItem {
                    Label("Yoga sequence", systemImage: "figure.cooldown")
                }
                .tag(0)

            PranayamaView()
                .tabItem {
                    Label("Pranayama", systemImage: "wind")
                }
                .tag(1)
            
            KriyaView()
                .tabItem {
                    Label("Kriya", systemImage: "flame")
                }
                .tag(2)
            
            CustomSequenceView()
                .tabItem {
                    Label("Custom", systemImage: "list.bullet.clipboard")
                }
                .tag(3)
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .onAppear {
            if !hasLaunchedBefore {
                showingHelp = true
                hasLaunchedBefore = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
