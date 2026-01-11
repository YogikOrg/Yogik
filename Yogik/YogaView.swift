//
//  YogaView.swift
//  Yogik
//
//  Created by Manbhawan on 11/01/2026.
//

import SwiftUI
import UIKit
import AVFoundation

struct YogaView: View {
    @State private var transitionSeconds: Int = 5
    @State private var holdSeconds: Int = 10
    @State private var remaining: Int = 0
    @State private var lapCount: Int = 0
    @State private var isPaused: Bool = false
    @State private var phase: Phase = .idle
    @State private var showingDial: Bool = false
    @State private var inSession: Bool = false
    @State private var inPrepPhase: Bool = false
    @State private var prepWorkItem: DispatchWorkItem?
    @AppStorage("progressSoundID") private var progressSoundID: Int = 1057
    @AppStorage("selectedVoiceID") private var selectedVoiceID: String = ""
    @AppStorage("prepTimeSeconds") private var prepTimeSeconds: Int = 5

    @StateObject private var session = YogaSessionManager()

    enum PickerSelection: String, Identifiable {
        case transition, hold
        var id: String { rawValue }
    }
    @State private var activePicker: PickerSelection? = nil
    @State private var showingSettings: Bool = false

    enum Phase {
        case idle, transition, hold
    }

    struct TimerSetup: Identifiable, Codable, Equatable {
        let id: UUID
        var transitionSeconds: Int
        var holdSeconds: Int
        var progressSoundID: Int
        var date: Date
        var laps: Int

        var name: String {
            "hold-\(holdSeconds)"
        }
    }

    @State private var history: [TimerSetup] = []
    private let historyKey = "Yogik.timerHistory"

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if showingDial {
                    // Dial-only UI
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                            .frame(width: 220, height: 220)

                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(phaseColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 220, height: 220)
                            .animation(.easeInOut(duration: 0.2), value: progress)

                        VStack {
                            Text(phaseText)
                                .font(.headline)
                                .foregroundColor(phaseColor)
                            Text("\(remaining) s")
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                            Text("Laps: \(lapCount)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 12)

                    HStack(spacing: 20) {
                        Button(action: togglePause) {
                            if isPaused {
                                Label("Resume", systemImage: "play.fill")
                            } else {
                                Label("Pause", systemImage: "pause.fill")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(!inSession || inPrepPhase)

                        Button(action: stopSession) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!inSession)
                    }
                    .padding()
                    Spacer()
                } else {
                    // Setup UI
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Text("Transition:").font(.subheadline).fontWeight(.semibold)
                            Spacer()
                            Button(action: {
                                guard !session.isRunning else { return }
                                transitionSeconds = min(max(transitionSeconds, 1), 60)
                                activePicker = .transition
                            }) {
                                HStack(spacing: 6) {
                                    Text("\(transitionSeconds) s")
                                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                            .disabled(session.isRunning)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        HStack(spacing: 12) {
                            Text("Hold:").font(.subheadline).fontWeight(.semibold)
                            Spacer()
                            Button(action: {
                                guard !session.isRunning else { return }
                                holdSeconds = min(max(holdSeconds, 1), 60)
                                activePicker = .hold
                            }) {
                                HStack(spacing: 6) {
                                    Text("\(holdSeconds) s")
                                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                            .disabled(session.isRunning)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                        Button(action: startSession) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Start")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .fontWeight(.semibold)
                        }
                        .disabled(session.isRunning || (transitionSeconds + holdSeconds) == 0)
                        
                        Divider()
                        
                        Text("Saved timers")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.top, 8)
                            .padding(.horizontal, 16)
                        
                        if history.isEmpty {
                            Text("No saved timers yet")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .padding(.horizontal, 16)
                        } else {
                            List {
                                ForEach(history) { item in
                                    Button(action: {
                                        transitionSeconds = item.transitionSeconds
                                        holdSeconds = item.holdSeconds
                                        progressSoundID = item.progressSoundID
                                        startSession()
                                        showingDial = true
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                Text(item.date, style: .date)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text("\(item.laps) laps")
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                Text("T:\(item.transitionSeconds) H:\(item.holdSeconds)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .listRowBackground(Color(.systemGray6))
                                    .listRowSeparator(.hidden)
                                }
                                .onDelete(perform: deleteHistory)
                            }
                            .listStyle(.plain)
                            .frame(maxHeight: .infinity)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Yoga")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image("BrandIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $activePicker) { selection in
                NavigationView {
                    VStack {
                        if selection == .transition {
                            Picker("Transition", selection: $transitionSeconds) {
                                ForEach(1...60, id: \.self) { i in
                                    Text("\(i) s").tag(i)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .labelsHidden()
                            .frame(maxHeight: 260)
                        } else {
                            Picker("Hold", selection: $holdSeconds) {
                                ForEach(1...60, id: \.self) { i in
                                    Text("\(i) s").tag(i)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .labelsHidden()
                            .frame(maxHeight: 260)
                        }
                        Spacer()
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { activePicker = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { activePicker = nil }
                        }
                    }
                    .navigationTitle(selection == .transition ? "Select Transition" : "Select Hold")
                }
            }
        }
        .onDisappear {
            stopSession()
        }
        .onAppear {
            loadHistory()
        }
    }

    private var currentPhaseTotal: Int {
        switch phase {
        case .transition:
            return max(transitionSeconds, 1)
        case .hold:
            return max(holdSeconds, 1)
        case .idle:
            return 1
        }
    }

    private var progress: Double {
        let total = currentPhaseTotal
        guard total > 0 else { return 0 }
        return 1.0 - Double(remaining) / Double(total)
    }

    private var phaseColor: Color {
        switch phase {
        case .transition: return Color.blue
        case .hold: return Color.green
        case .idle: return Color.gray
        }
    }

    private var phaseText: String {
        switch phase {
        case .idle: return "Idle"
        case .transition: return "Transition"
        case .hold: return "Hold"
        }
    }

    private func startSession() {
        guard session.state == .idle else { return }
        let total = transitionSeconds + holdSeconds
        guard total > 0 else { return }

        addOrUpdateHistoryOnStart()

        lapCount = 0
        isPaused = false
        inSession = true
        inPrepPhase = true

        if transitionSeconds > 0 {
            phase = .transition
            remaining = transitionSeconds
        } else if holdSeconds > 0 {
            phase = .hold
            remaining = holdSeconds
        } else {
            phase = .idle
            remaining = 0
            inSession = false
            inPrepPhase = false
            return
        }

        // Call prep prompt before starting
        AudioManager.shared.speak(message: "Prepare for the session. Move into first pose", voiceID: selectedVoiceID, rate: 0.5)

        // Delay timer start to allow prep time
        let workItem = DispatchWorkItem {
            self.inPrepPhase = false
            self.session.start {
                self.tick()
            }
        }
        prepWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(prepTimeSeconds), execute: workItem)
        
        UIApplication.shared.isIdleTimerDisabled = true
        showingDial = true
    }

    private func stopSession() {
        AudioManager.shared.stopSpeaking()
        prepWorkItem?.cancel()
        prepWorkItem = nil
        session.stop()
        phase = .idle
        remaining = 0
        lapCount = 0
        isPaused = false
        showingDial = false
        inSession = false
        inPrepPhase = false
        updateHistoryOnStop()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func togglePause() {
        if isPaused {
            session.resume()
        } else {
            session.pause()
        }
        isPaused.toggle()
    }

    private func tick() {
        remaining = session.remaining

        if remaining > 0 {
            if phase == .hold && remaining > 0 && progressSoundID != 0 {
                AudioManager.shared.playSound(soundID: progressSoundID)
            }
            remaining -= 1
            session.remaining = remaining
            return
        }

        switch phase {
        case .transition:
            if holdSeconds > 0 {
                phase = .hold
                remaining = holdSeconds
                AudioManager.shared.speak(message: "Hold", voiceID: selectedVoiceID, rate: 0.5)
            } else {
                lapCount += 1
                if transitionSeconds > 0 {
                    phase = .transition
                    remaining = transitionSeconds
                    AudioManager.shared.speak(message: "Move to next pose", voiceID: selectedVoiceID, rate: 0.5)
                } else if holdSeconds > 0 {
                    phase = .hold
                    remaining = holdSeconds
                } else {
                    stopSession()
                }
            }

        case .hold:
            lapCount += 1
            if transitionSeconds > 0 {
                phase = .transition
                remaining = transitionSeconds
                AudioManager.shared.speak(message: "Move to next pose", voiceID: selectedVoiceID, rate: 0.5)
            } else if holdSeconds > 0 {
                phase = .hold
                remaining = holdSeconds
            } else {
                stopSession()
            }

        case .idle:
            stopSession()
        }
        
        session.remaining = remaining
    }

    // MARK: - History
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([TimerSetup].self, from: data)
            history = decoded
        } catch { }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch { }
    }

    private func addOrUpdateHistoryOnStart() {
        let now = Date()
        if let idx = history.firstIndex(where: { $0.transitionSeconds == transitionSeconds && $0.holdSeconds == holdSeconds && $0.progressSoundID == progressSoundID }) {
            var e = history.remove(at: idx)
            e.date = now
            e.laps = 0
            history.insert(e, at: 0)
        } else {
            let entry = TimerSetup(id: UUID(), transitionSeconds: transitionSeconds, holdSeconds: holdSeconds, progressSoundID: progressSoundID, date: now, laps: 0)
            history.insert(entry, at: 0)
            if history.count > 5 {
                history.removeLast()
            }
        }
        saveHistory()
    }

    private func updateHistoryOnStop() {
        if let idx = history.firstIndex(where: { $0.transitionSeconds == transitionSeconds && $0.holdSeconds == holdSeconds && $0.progressSoundID == progressSoundID }) {
            history[idx].laps = lapCount
            history[idx].date = Date()
            let e = history.remove(at: idx)
            history.insert(e, at: 0)
            if history.count > 5 { history.removeLast() }
            saveHistory()
        }
    }

    private func deleteHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        saveHistory()
    }
}

#Preview {
    YogaView()
}
