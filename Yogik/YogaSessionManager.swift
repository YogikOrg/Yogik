//
//  YogaSessionManager.swift
//  Yogik
//
//  Created by Manbhawan on 11/01/2026.
//

import Foundation
import Combine

class YogaSessionManager: ObservableObject {
    enum SessionState {
        case idle
        case active
        case paused
    }
    
    @Published var state: SessionState = .idle
    @Published var remaining: Int = 0
    @Published var isPaused: Bool = false
    
    private var timer: Timer?
    private var tickHandler: (() -> Void)?
    
    var isRunning: Bool {
        state == .active && !isPaused
    }
    
    func start(tickHandler: @escaping () -> Void) {
        guard state == .idle else { return }
        
        self.tickHandler = tickHandler
        state = .active
        isPaused = false
        startTimer()
    }
    
    func pause() {
        guard state == .active else { return }
        isPaused = true
        timer?.invalidate()
        timer = nil
    }
    
    func resume() {
        guard state == .active && isPaused else { return }
        isPaused = false
        startTimer()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        state = .idle
        isPaused = false
        remaining = 0
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickHandler?()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    deinit {
        timer?.invalidate()
    }
}
