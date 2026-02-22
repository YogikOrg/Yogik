//
//  PranayamaSessionManager.swift
//  Yogik
//
//  Created by Manbhawan on 11/01/2026.
//

import Foundation
import Combine

class PranayamaSessionManager: ObservableObject {
    enum SessionState {
        case idle
        case active
        case paused
    }
    
    @Published var state: SessionState = .idle
    @Published var remaining: Int = 0
    @Published var isPaused: Bool = false
    
    private var timer: Timer?
    private var tickHandler: ((Double) -> Void)?
    private var timerInterval: Double = 0.1
    
    var isRunning: Bool {
        state == .active && !isPaused
    }
    
    func start(tickHandler: @escaping (Double) -> Void) {
        guard state == .idle else { return }
        
        self.tickHandler = tickHandler
        state = .active
        isPaused = false
        startTimer()
    }
    
    // Overload allowing a configurable tick interval
    func start(tickInterval: Double, tickHandler: @escaping (Double) -> Void) {
        guard state == .idle else { return }
        
        self.timerInterval = max(0.01, tickInterval)
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
        let t = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tickHandler?(self.timerInterval)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    
    deinit {
        timer?.invalidate()
    }
}
