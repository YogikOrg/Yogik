//
//  YogikApp.swift
//  Yogik
//
//  Created by Manbhawan on 08/01/2026.
//

import SwiftUI

@main
struct YogikApp: App {
    init() {
        // Initialize AudioManager early on app launch to preload speech synthesizer
        // This prevents delays when playing the first voice prompt
        // Give it a moment to fully initialize
        _ = AudioManager.shared
        Thread.sleep(forTimeInterval: 0.1)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
