//
//  KriyaView.swift
//  Yogik
//
//  Created by Manbhawan on 17/01/2026.
//

import SwiftUI
import AVFoundation

struct KriyaView: View {
    struct Stage: Identifiable, Codable {
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
        let stages: [Stage]
        let kriyaBreathInLabel: String
        let kriyaBreathOutLabel: String
        let repeatCount: Int
        
        init(id: UUID = UUID(), name: String, stages: [Stage], kriyaBreathInLabel: String = "Inhale", kriyaBreathOutLabel: String = "Exhale", repeatCount: Int = 1) {
            self.id = id
            self.name = name
            self.stages = stages
            self.kriyaBreathInLabel = kriyaBreathInLabel
            self.kriyaBreathOutLabel = kriyaBreathOutLabel
            self.repeatCount = repeatCount
        }
    }
    
    @State private var stages: [Stage] = [Stage()]
    @State private var currentStageIndex: Int = 0
    @State private var currentStageCount: Int = 1
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

    private let stageCountOptions: [Int] = {
        var values: [Int] = []
        values.append(contentsOf: 1...5)
        values.append(contentsOf: stride(from: 10, through: 50, by: 5))
        values.append(contentsOf: stride(from: 75, through: 500, by: 25))
        values.append(contentsOf: stride(from: 550, through: 1000, by: 50))
        return values
    }()
    
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
                                    Text("Stage")
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
                            
                            ForEach($stages) { $stage in
                                HStack(spacing: 0) {
                                    Text("\(stages.firstIndex(where: { $0.id == stage.id })! + 1)")
                                        .font(.caption)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Menu {
                                        ForEach(Array(stride(from: 0.5, through: 3.0, by: 0.5)), id: \.self) { value in
                                            Button("\(String(format: "%.1f", value))s") {
                                                stage.breathInSeconds = value
                                            }
                                        }
                                    } label: {
                                        Text(String(format: "%.1f", stage.breathInSeconds))
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
                                                stage.breathOutSeconds = value
                                            }
                                        }
                                    } label: {
                                        Text(String(format: "%.1f", stage.breathOutSeconds))
                                            .font(.caption)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 8)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    Menu {
                                        ForEach(stageCountOptions, id: \.self) { value in
                                            Button("\(value)") {
                                                stage.counts = value
                                            }
                                        }
                                    } label: {
                                        Text("\(stage.counts)")
                                            .font(.caption)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 8)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .padding(.vertical, 6)
                            }
                            .onDelete(perform: deleteStage)
                            
                            Button(action: addStage) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle")
                                    Text("Add Stage")
                                }
                            }
                        }
                        
                        Section {
                            Picker("Repetition", selection: $repeatCount) {
                                ForEach(1...10, id: \.self) { value in
                                    Text("\(value)").tag(value)
                                }
                            }
                            .pickerStyle(.menu)
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
                            .disabled(session.isRunning || stages.isEmpty)
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
                                            Text("\(saved.stages.count) stage\(saved.stages.count == 1 ? "" : "s")")
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
        guard !stages.isEmpty else { return }
        
        // Auto-save if user provided a name
        let trimmedName = kriyaName.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            saveKriya()
        }
        
        currentStageIndex = 0
        currentStageCount = 1
        remainingRepeats = repeatCount - 1
        elapsed = 0
        elapsedFractional = 0.0
        isPaused = false
        inSession = true
        inPrepPhase = true
        
        AudioManager.shared.speak(message: "Prepare for breathing exercise. Take position.", voiceID: selectedVoiceID, rate: 0.5)
        
        let workItem = DispatchWorkItem {
            self.inPrepPhase = false
            self.playCurrentStage()
            
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
        currentStageIndex = 0
        currentStageCount = 1
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
        
        let currentStage = stages[currentStageIndex]
        
        if elapsedFractional >= currentPhaseDuration {
            // Phase complete, move to next
            switch phase {
            case .breathIn:
                if currentStage.breathOutSeconds > 0 {
                    phase = .breathOut
                    elapsed = 0
                    elapsedFractional = 0.0
                    let rate = getVoiceRateForDuration(currentStage.breathOutSeconds)
                    AudioManager.shared.speak(message: kriyaBreathOutLabel, voiceID: selectedVoiceID, rate: rate)
                } else {
                    moveToNextStage()
                }
            case .breathOut:
                moveToNextStage()
            case .idle:
                stop()
            }
        }
    }
    
    private func moveToNextStage() {
        let currentStage = stages[currentStageIndex]
        if currentStageCount < currentStage.counts {
            // Repeat current stage
            currentStageCount += 1
            playCurrentStage()
        } else if currentStageIndex < stages.count - 1 {
            // Move to next stage
            currentStageIndex += 1
            currentStageCount = 1
            playCurrentStage()
        } else if remainingRepeats > 0 {
            // All stages complete, repeat the entire sequence
            remainingRepeats -= 1
            currentStageIndex = 0
            currentStageCount = 1
            playCurrentStage()
        } else {
            // All stages and repeats complete, show ending prompt
            phase = .idle
            session.pause()
            showingEndPrompt = true
            AudioManager.shared.speak(message: "Relax, take few long and deep breaths", voiceID: selectedVoiceID, rate: 0.5)
        }
    }
    
    private func playCurrentStage() {
        let stage = stages[currentStageIndex]
        if stage.breathInSeconds > 0 {
            phase = .breathIn
            elapsed = 0
            elapsedFractional = 0.0
            let rate = getVoiceRateForDuration(stage.breathInSeconds)
            AudioManager.shared.speak(message: kriyaBreathInLabel, voiceID: selectedVoiceID, rate: rate)
        } else if stage.breathOutSeconds > 0 {
            phase = .breathOut
            elapsed = 0
            elapsedFractional = 0.0
            let rate = getVoiceRateForDuration(stage.breathOutSeconds)
            AudioManager.shared.speak(message: kriyaBreathOutLabel, voiceID: selectedVoiceID, rate: rate)
        }
    }
    
    private var currentPhaseDuration: Double {
        guard currentStageIndex < stages.count else { return 1.0 }
        let stage = stages[currentStageIndex]
        switch phase {
        case .breathIn: return stage.breathInSeconds
        case .breathOut: return stage.breathOutSeconds
        case .idle: return 1.0
        }
    }
    
    private func addStage() {
        stages.append(Stage())
    }
    
    private func deleteStage(at offsets: IndexSet) {
        stages.remove(atOffsets: offsets)
    }
    
    private func getSavedKriyas() -> [SavedKriya] {
        guard let data = UserDefaults.standard.data(forKey: "savedKriyas") else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([SavedKriya].self, from: data)) ?? []
    }
    
    private func saveKriya() {
        let trimmedName = kriyaName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !stages.isEmpty else { return }
        
        var allKriyas = getSavedKriyas()
        let newKriya = SavedKriya(
            name: trimmedName,
            stages: stages,
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
        stages = kriya.stages
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
