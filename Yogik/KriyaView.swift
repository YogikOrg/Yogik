//
//  KriyaView.swift
//  Yogik
//
//  Created by Manbhawan on 17/01/2026.
//

import SwiftUI
import AVFoundation

struct KriyaView: View {
    struct Round: Identifiable, Codable {
        let id: UUID
        var breathInSeconds: Double
        var breathOutSeconds: Double
        var counts: Int
        
        init(id: UUID = UUID(), breathInSeconds: Double = 1.0, breathOutSeconds: Double = 1.0, counts: Int = 20) {
            self.id = id
            self.breathInSeconds = breathInSeconds
            self.breathOutSeconds = breathOutSeconds
            self.counts = counts
        }
    }
    
    struct SavedKriya: Codable, Identifiable {
        let id: UUID
        let name: String
        let rounds: [Round]
        let kriyaBreathInLabel: String
        let kriyaBreathOutLabel: String
        let repeatCount: Int
        
        init(id: UUID = UUID(), name: String, rounds: [Round], kriyaBreathInLabel: String = "Inhale", kriyaBreathOutLabel: String = "Exhale", repeatCount: Int = 1) {
            self.id = id
            self.name = name
            self.rounds = rounds
            self.kriyaBreathInLabel = kriyaBreathInLabel
            self.kriyaBreathOutLabel = kriyaBreathOutLabel
            self.repeatCount = repeatCount
        }
    }
    
    @State private var rounds: [Round] = [Round()]
    @State private var currentRoundIndex: Int = 0
    @State private var currentRoundCount: Int = 1
    @State private var kriyaBreathInLabel: String = "In"
    @State private var kriyaBreathOutLabel: String = "Out"
    @State private var kriyaName: String = ""
    @State private var repeatCount: Int = 1
    @State private var remainingRepeats: Int = 0
    @State private var elapsed: Int = 0
    @State private var elapsedFractional: Double = 0.0
    @State private var isPaused: Bool = false
    @State private var showingDial: Bool = false
    @State private var inSession: Bool = false
    @State private var inPrepPhase: Bool = false
    @State private var showingEndPrompt: Bool = false
    @State private var prepWorkItem: DispatchWorkItem?
    
    @AppStorage("selectedVoiceID") private var selectedVoiceID: String = ""
    @AppStorage("prepTimeSeconds") private var prepTimeSeconds: Int = 5
    @AppStorage("breathInLabel") private var breathInLabel: String = "Inhale"
    @AppStorage("breathOutLabel") private var breathOutLabel: String = "Exhale"
    @AppStorage("savedKriyas") private var savedKriyas: Data = Data()
    
    @StateObject private var session = PranayamaSessionManager()
    
    enum Phase {
        case idle, breathIn, breathOut
    }
    @State private var phase: Phase = .idle
    @State private var showingSettings: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if showingDial {
                    if showingEndPrompt {
                        // End Prompt UI
                        VStack(spacing: 40) {
                            Spacer()
                            VStack(spacing: 20) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                                Text("Relax, take few long and deep breaths")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 30)
                    } else {
                        // Dial UI
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
                                Text("\(elapsed)")
                                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                            }
                        }
                        .padding(.top, 12)
                    }
                    
                    if showingEndPrompt {
                        HStack(spacing: 20) {
                            Button(action: stop) {
                                Label("Done", systemImage: "checkmark.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else {
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

                            Button(action: stop) {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!inSession)
                        }
                        .padding()
                    }
                    Spacer()
                } else {
                    // Setup UI
                    Form {
                        Section {
                                    HStack {
                                        Text("Kriya name")
                                        Spacer()
                                        TextField("Enter name", text: $kriyaName)
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                                
                                Section {
                                    HStack {
                                        Text("Breath-in text")
                                        Spacer()
                                        TextField("", text: $kriyaBreathInLabel)
                                            .multilineTextAlignment(.trailing)
                                    }
                                    HStack {
                                        Text("Breathout text")
                                        Spacer()
                                        TextField("", text: $kriyaBreathOutLabel)
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                        
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 0) {
                                    Text("Round")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("In time")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                    Text("Out time")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                    Text("Count")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .padding(.bottom, 8)
                            }
                            
                            ForEach($rounds) { $round in
                                HStack(spacing: 0) {
                                    Text("\(rounds.firstIndex(where: { $0.id == round.id })! + 1)")
                                        .font(.caption)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Menu {
                                        ForEach(Array(stride(from: 0.5, through: 3.0, by: 0.5)), id: \.self) { value in
                                            Button("\(String(format: "%.1f", value))s") {
                                                round.breathInSeconds = value
                                            }
                                        }
                                    } label: {
                                        Text(String(format: "%.1f", round.breathInSeconds))
                                            .font(.caption)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 8)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    Menu {
                                        ForEach(Array(stride(from: 0.5, through: 3.0, by: 0.5)), id: \.self) { value in
                                            Button("\(String(format: "%.1f", value))s") {
                                                round.breathOutSeconds = value
                                            }
                                        }
                                    } label: {
                                        Text(String(format: "%.1f", round.breathOutSeconds))
                                            .font(.caption)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 8)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    TextField("", value: $round.counts, format: .number)
                                        .keyboardType(.numberPad)
                                        .font(.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(4)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .padding(.vertical, 6)
                            }
                            .onDelete(perform: deleteRound)
                            
                            Button(action: addRound) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle")
                                    Text("Add Round")
                                }
                            }
                        }
                        
                        Section {
                            HStack {
                                Text("Repetition")
                                Spacer()
                                TextField("", value: $repeatCount, format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 60)
                            }
                        }
                        
                        Section {
                            Button(action: { start(); showingDial = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                    Text("Start")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(session.isRunning || rounds.isEmpty)
                        }
                        
                        if !getSavedKriyas().isEmpty {
                            Section {
                                ForEach(getSavedKriyas()) { saved in
                                    Button(action: { loadKriya(saved) }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(saved.name)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                            Text("\(saved.rounds.count) round\(saved.rounds.count == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .onDelete { indexSet in
                                    let kriyas = getSavedKriyas()
                                    for index in indexSet {
                                        if index < kriyas.count {
                                            deleteSavedKriya(kriyas[index])
                                        }
                                    }
                                }
                            } header: {
                                Text("Saved Kriyas")
                            }
                        }
                    }
                    Spacer()
                }
            }
            .navigationTitle("Kriya")
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
            .onDisappear {
                stop()
            }
        }
    }
    
    private var progress: Double {
        guard currentPhaseDuration > 0 else { return 0 }
        return elapsedFractional / currentPhaseDuration
    }
    
    private var currentPhaseTotal: Double {
        currentPhaseDuration
    }
    
    private var phaseColor: Color {
        switch phase {
        case .breathIn: return Color.green
        case .breathOut: return Color.orange
        case .idle: return Color.gray
        }
    }
    
    private var phaseText: String {
        switch phase {
        case .idle: return "Idle"
        case .breathIn: return kriyaBreathInLabel
        case .breathOut: return kriyaBreathOutLabel
        }
    }
    
    private func getVoiceRateForDuration(_ duration: Double) -> Float {
        switch duration {
        case ..<1.0:
            return 0.5
        case 1.0..<1.5:
            return 0.3
        case 1.5..<3.0:
            return 0.05
        default:
            return 0.05
        }
    }
    
    private func start() {
        guard session.state == .idle else { return }
        guard !rounds.isEmpty else { return }
        
        // Auto-save if user provided a name
        let trimmedName = kriyaName.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            saveKriya()
        }
        
        currentRoundIndex = 0
        currentRoundCount = 1
        remainingRepeats = repeatCount - 1
        elapsed = 0
        elapsedFractional = 0.0
        isPaused = false
        inSession = true
        inPrepPhase = true
        
        AudioManager.shared.speak(message: "Prepare for breathing exercise. Take position.", voiceID: selectedVoiceID, rate: 0.5)
        
        let workItem = DispatchWorkItem {
            self.inPrepPhase = false
            self.playCurrentRound()
            
            // Start session with 0.1s tick interval
            self.session.start { timeInterval in
                self.tick(timeInterval: timeInterval)
            }
        }
        prepWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(prepTimeSeconds), execute: workItem)
        
        UIApplication.shared.isIdleTimerDisabled = true
        showingDial = true
    }
    
    private func stop() {
        AudioManager.shared.stopSpeaking()
        prepWorkItem?.cancel()
        prepWorkItem = nil
        session.stop()
        phase = .idle
        elapsed = 0
        elapsedFractional = 0.0
        isPaused = false
        showingDial = false
        showingEndPrompt = false
        inSession = false
        inPrepPhase = false
        currentRoundIndex = 0
        currentRoundCount = 1
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    private func togglePause() {
        guard session.state == .active else { return }
        if isPaused {
            isPaused = false
            session.resume()
        } else {
            isPaused = true
            session.pause()
        }
    }
    
    private func tick(timeInterval: Double) {
        elapsedFractional += timeInterval
        elapsed = Int(elapsedFractional)
        
        let currentRound = rounds[currentRoundIndex]
        
        if elapsedFractional >= currentPhaseDuration {
            // Phase complete, move to next
            switch phase {
            case .breathIn:
                if currentRound.breathOutSeconds > 0 {
                    phase = .breathOut
                    elapsed = 0
                    elapsedFractional = 0.0
                    let rate = getVoiceRateForDuration(currentRound.breathOutSeconds)
                    AudioManager.shared.speak(message: kriyaBreathOutLabel, voiceID: selectedVoiceID, rate: rate)
                } else {
                    moveToNextRound()
                }
            case .breathOut:
                moveToNextRound()
            case .idle:
                stop()
            }
        }
    }
    
    private func moveToNextRound() {
        let currentRound = rounds[currentRoundIndex]
        if currentRoundCount < currentRound.counts {
            // Repeat current round
            currentRoundCount += 1
            playCurrentRound()
        } else if currentRoundIndex < rounds.count - 1 {
            // Move to next round
            currentRoundIndex += 1
            currentRoundCount = 1
            playCurrentRound()
        } else if remainingRepeats > 0 {
            // All rounds complete, repeat the entire sequence
            remainingRepeats -= 1
            currentRoundIndex = 0
            currentRoundCount = 1
            playCurrentRound()
        } else {
            // All rounds and repeats complete, show ending prompt
            phase = .idle
            session.pause()
            showingEndPrompt = true
            AudioManager.shared.speak(message: "Relax, take few long and deep breaths", voiceID: selectedVoiceID, rate: 0.5)
        }
    }
    
    private func playCurrentRound() {
        let round = rounds[currentRoundIndex]
        if round.breathInSeconds > 0 {
            phase = .breathIn
            elapsed = 0
            elapsedFractional = 0.0
            let rate = getVoiceRateForDuration(round.breathInSeconds)
            AudioManager.shared.speak(message: kriyaBreathInLabel, voiceID: selectedVoiceID, rate: rate)
        } else if round.breathOutSeconds > 0 {
            phase = .breathOut
            elapsed = 0
            elapsedFractional = 0.0
            let rate = getVoiceRateForDuration(round.breathOutSeconds)
            AudioManager.shared.speak(message: kriyaBreathOutLabel, voiceID: selectedVoiceID, rate: rate)
        }
    }
    
    private var currentPhaseDuration: Double {
        guard currentRoundIndex < rounds.count else { return 1.0 }
        let round = rounds[currentRoundIndex]
        switch phase {
        case .breathIn: return round.breathInSeconds
        case .breathOut: return round.breathOutSeconds
        case .idle: return 1.0
        }
    }
    
    private func addRound() {
        rounds.append(Round())
    }
    
    private func deleteRound(at offsets: IndexSet) {
        rounds.remove(atOffsets: offsets)
    }
    
    private func getSavedKriyas() -> [SavedKriya] {
        guard let data = UserDefaults.standard.data(forKey: "savedKriyas") else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([SavedKriya].self, from: data)) ?? []
    }
    
    private func saveKriya() {
        let trimmedName = kriyaName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !rounds.isEmpty else { return }
        
        var allKriyas = getSavedKriyas()
        let newKriya = SavedKriya(
            name: trimmedName,
            rounds: rounds,
            kriyaBreathInLabel: kriyaBreathInLabel,
            kriyaBreathOutLabel: kriyaBreathOutLabel,
            repeatCount: repeatCount
        )
        allKriyas.append(newKriya)
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(allKriyas) {
            UserDefaults.standard.set(encoded, forKey: "savedKriyas")
            kriyaName = ""
        }
    }
    
    private func loadKriya(_ kriya: SavedKriya) {
        rounds = kriya.rounds
        kriyaBreathInLabel = kriya.kriyaBreathInLabel
        kriyaBreathOutLabel = kriya.kriyaBreathOutLabel
        repeatCount = kriya.repeatCount
        kriyaName = ""
        start()
        showingDial = true
    }
    
    private func deleteSavedKriya(_ kriya: SavedKriya) {
        var allKriyas = getSavedKriyas()
        allKriyas.removeAll { $0.id == kriya.id }
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(allKriyas) {
            UserDefaults.standard.set(encoded, forKey: "savedKriyas")
        }
    }
}

#Preview {
    KriyaView()
}
