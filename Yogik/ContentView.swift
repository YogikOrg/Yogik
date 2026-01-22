//
//  ContentView.swift
//  Yogik
//
//  Created by Manbhawan on 08/01/2026.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("selectedTab") private var selectedTab = 0
    
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
    }
}

#Preview {
    ContentView()
}
