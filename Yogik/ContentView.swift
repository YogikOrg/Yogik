//
//  ContentView.swift
//  Yogik
//
//  Created by Manbhawan on 08/01/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            YogaView()
                .tabItem {
                    Label("Yoga", systemImage: "figure.cooldown")
                }

            PranayamaView()
                .tabItem {
                    Label("Pranayama", systemImage: "wind")
                }
        }
    }
}

#Preview {
    ContentView()
}
