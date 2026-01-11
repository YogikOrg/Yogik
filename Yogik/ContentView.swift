//
//  ContentView.swift
//  Yogik
//
//  Created by Manbhawan on 08/01/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            PranayamaView()
                .tabItem {
                    Label("Pranayama", systemImage: "wind")
                }
                .tag(0)

            YogaView()
                .tabItem {
                    Label("Yoga", systemImage: "figure.cooldown")
                }
                .tag(1)
        }
    }
}

#Preview {
    ContentView()
}
