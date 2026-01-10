//
//  ContentView.swift
//  Yogik
//
//  Created by Manbhawan on 08/01/2026.
//

import SwiftUI
import AudioToolbox
import UIKit

struct ContentView: View {
    @State private var transitionSeconds: Int = 5
    @State private var holdSeconds: Int = 10
    @State private var isRunning: Bool = false
    @State private var remaining: Int = 0
    @State private var lapCount: Int = 0
    @State private var timer: Timer? = nil
    @State private var isPaused: Bool = false
    @State private var phase: Phase = .idle
    @State private var showingDial: Bool = false
    @AppStorage("progressSoundID") private var progressSoundID: Int = 1057
    @AppStorage("poseEndChimeID") private var poseEndChimeID: Int = 1115

    // active picker sheet (nil = none)
    enum PickerSelection: String, Identifiable {
        case transition, hold
        var id: String { rawValue }
    }
    @State private var activePicker: PickerSelection? = nil
    @State private var showingSettings: Bool = false

    private let systemChimeOptions: [(id: Int, name: String)] = [
        // None option
        (0, "None"),
        // Bells and chimes
        (1000, "Marimba"),
        (1001, "Alarm"),
        (1003, "Tink"),
        (1004, "Ping"),
        (1005, "Pop"),
        (1006, "Tock"),
        (1007, "Xylophone"),
        (1016, "Glass"),
        (1020, "Strum"),
        (1024, "Pebble"),
        (1057, "Chord"),
        (1058, "Chime"),
        (1111, "Bamboo"),
        (1112, "Nairobi"),
        (1113, "Plink"),
        (1114, "Pizzicato"),
        (1115, "Bell"),
        (1116, "Beep"),
        (1117, "Bright"),
        (1118, "Happy"),
        (1119, "Jolly"),
        (1120, "Ladder"),
        (1121, "Mallet"),
        (1122, "Metronome"),
        (1123, "Nictitate"),
        (1124, "Perplexed"),
        (1125, "Smart"),
        (1126, "Subtle"),
        (1127, "Trill"),
        (1128, "Tuning")
    ]

    enum Phase {
        case idle, transition, hold
    }

    // Recent timer setups (persisted)
    struct TimerSetup: Identifiable, Codable, Equatable {
        let id: UUID
        var transitionSeconds: Int
        var holdSeconds: Int
        var progressSoundID: Int
        var poseEndChimeID: Int
        var date: Date
        var laps: Int

        var name: String {
            "hold-\(holdSeconds)"
        }
    }

    @State private var history: [TimerSetup] = []
    private let historyKey = "Yogik.timerHistory"

    var body: some View {
        TabView {
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
                        .disabled(!isRunning)

                        Button(action: stop) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isRunning)
                    }
                    .padding()
                    Spacer()
                } else {
                    // Setup UI: merged Timer Setup + Saved timers
                    Form {
                        Section(header: Text("Timer Setup")) {
                            // Compact rows that open wheel pickers in a sheet
                            Button(action: {
                                guard !isRunning else { return }
                                // clamp value into 1...60 before presenting
                                transitionSeconds = min(max(transitionSeconds, 1), 60)
                                activePicker = .transition
                            }) {
                                HStack {
                                    Text("Transition: \(transitionSeconds) s")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .disabled(isRunning)

                            Button(action: {
                                guard !isRunning else { return }
                                holdSeconds = min(max(holdSeconds, 1), 60)
                                activePicker = .hold
                            }) {
                                HStack {
                                    Text("Hold: \(holdSeconds) s")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .disabled(isRunning)

                            // Chime settings moved to dedicated Settings screen (gear)

                            Button(action: { start(); showingDial = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                    Text("Start")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isRunning || (transitionSeconds + holdSeconds) == 0)
                        }

                        Section(header: Text("Saved timers")) {
                            if history.isEmpty {
                                Text("No saved timers yet")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(history) { item in
                                    Button(action: {
                                        transitionSeconds = item.transitionSeconds
                                        holdSeconds = item.holdSeconds
                                        progressSoundID = item.progressSoundID
                                        poseEndChimeID = item.poseEndChimeID
                                        start()
                                        showingDial = true
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(item.name)
                                                    .font(.headline)
                                                Text(item.date, style: .date)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing) {
                                                Text("\(item.laps) laps")
                                                    .font(.subheadline)
                                                Text("T:\(item.transitionSeconds) H:\(item.holdSeconds)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .buttonStyle(.automatic)
                                }
                                .onDelete(perform: deleteHistory)
                            }
                        }
                    }
                    Spacer()
                }
            }
            .navigationTitle("Yogik")
            .toolbar {
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
                stop()
            }
            .onAppear {
                loadHistory()
            }
            .tabItem {
                Label("Yoga", systemImage: "figure.cooldown")
            }

            // Second tab: Pranayama
            PranayamaView()
                .tabItem {
                    Label("Pranayama", systemImage: "wind")
                }
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

    private func start() {
        guard !isRunning else { return }
        let total = transitionSeconds + holdSeconds
        guard total > 0 else { return }

        addOrUpdateHistoryOnStart()

        lapCount = 0
        isRunning = true
        isPaused = false

        if transitionSeconds > 0 {
            phase = .transition
            remaining = transitionSeconds
        } else if holdSeconds > 0 {
            phase = .hold
            remaining = holdSeconds
        } else {
            phase = .idle
            remaining = 0
            isRunning = false
            return
        }

        // schedule timer on main runloop
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
        
        // Keep screen awake while timer is running
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        phase = .idle
        // update history with the lap count for the last used setup (before resetting)
        updateHistoryOnStop()
        remaining = 0
        lapCount = 0
        isPaused = false
        // Return to the setup UI
        showingDial = false
        
        // Allow screen to sleep again
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func togglePause() {
        guard isRunning else { return }
        if isPaused {
            // resume
            isPaused = false
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                tick()
            }
            RunLoop.main.add(timer!, forMode: .common)
        } else {
            // pause
            timer?.invalidate()
            timer = nil
            isPaused = true
        }
    }

    private func tick() {
        if remaining > 0 {
            // Play progress sound every second during hold phase
            if phase == .hold && remaining > 0 && progressSoundID != 0 {
                playChime(soundID: progressSoundID)
            }
            remaining -= 1
            return
        }

        // When remaining reaches 0 at the start of tick, advance phases
        switch phase {
        case .transition:
            if holdSeconds > 0 {
                phase = .hold
                remaining = holdSeconds
            } else {
                // hold is 0 -> a lap completes immediately
                lapCount += 1
                playChime(soundID: poseEndChimeID)
                // Start next lap
                if transitionSeconds > 0 {
                    phase = .transition
                    remaining = transitionSeconds
                } else if holdSeconds > 0 {
                    phase = .hold
                    remaining = holdSeconds
                } else {
                    // both zero: nothing to do
                    stop()
                }
            }

        case .hold:
            // end of lap
            lapCount += 1
            playChime(soundID: poseEndChimeID)
            // Start next lap depending on configured times
            if transitionSeconds > 0 {
                phase = .transition
                remaining = transitionSeconds
            } else if holdSeconds > 0 {
                // transition is zero, continue with hold-only laps
                phase = .hold
                remaining = holdSeconds
            } else {
                stop()
            }

        case .idle:
            // shouldn't happen while running, but guard
            stop()
        }
    }

    // MARK: - History persistence
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([TimerSetup].self, from: data)
            history = decoded
        } catch {
            // ignore parse errors
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            // ignore
        }
    }

    private func addOrUpdateHistoryOnStart() {
        // create a new entry for this setup (or move existing to front)
        let now = Date()
        if let idx = history.firstIndex(where: { $0.transitionSeconds == transitionSeconds && $0.holdSeconds == holdSeconds && $0.progressSoundID == progressSoundID && $0.poseEndChimeID == poseEndChimeID }) {
            // move to front and update date/laps
            var e = history.remove(at: idx)
            e.date = now
            e.laps = 0
            history.insert(e, at: 0)
        } else {
            let entry = TimerSetup(id: UUID(), transitionSeconds: transitionSeconds, holdSeconds: holdSeconds, progressSoundID: progressSoundID, poseEndChimeID: poseEndChimeID, date: now, laps: 0)
            history.insert(entry, at: 0)
            if history.count > 5 {
                history.removeLast()
            }
        }
        saveHistory()
    }

    private func updateHistoryOnStop() {
        // find matching entry and update laps and date
        if let idx = history.firstIndex(where: { $0.transitionSeconds == transitionSeconds && $0.holdSeconds == holdSeconds && $0.progressSoundID == progressSoundID && $0.poseEndChimeID == poseEndChimeID }) {
            history[idx].laps = lapCount
            history[idx].date = Date()
            // move to front
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

    private func playChime(soundID: Int) {
        // Play the system sound if not "None" (id: 0)
        guard soundID != 0 else { return }
        AudioServicesPlaySystemSound(SystemSoundID(soundID))
    }

    // Bundled chime support removed; we play system sounds selected by the user.
}

#Preview {
    ContentView()
}
