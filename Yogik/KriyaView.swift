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
        let roundCount: Int
        
        init(id: UUID = UUID(), name: String, stages: [Stage], kriyaBreathInLabel: String = "Inhale", kriyaBreathOutLabel: String = "Exhale", roundCount: Int = 1) {
            self.id = id
            self.name = name
            self.stages = stages
            self.kriyaBreathInLabel = kriyaBreathInLabel
            self.kriyaBreathOutLabel = kriyaBreathOutLabel
            self.roundCount = roundCount
        }
    }
    
    @State private var stages: [Stage] = [Stage()]
    @State private var currentStageIndex: Int = 0
    @State private var currentStageCount: Int = 1
    @State private var kriyaBreathInLabel: String = "In"
    @State private var kriyaBreathOutLabel: String = "Out"
    @State private var kriyaName: String = ""
    @State private var roundCount: Int = 1
    @State private var remainingRounds: Int = 0
    @State private var elapsed: Int = 0
    @State private var elapsedFractional: Double = 0.0
    @State private var isPaused: Bool = false
    @State private var showingDial: Bool = false
    @State private var inSession: Bool = false
    @State private var inPrepPhase: Bool = false
    @State private var showingEndPrompt: Bool = false
    @State private var prepWorkItem: DispatchWorkItem?
    @State private var restPrepPromptSpoken: Bool = false
    @State private var showValidationAlert: Bool = false
    @State private var validationMessage: String = ""
    @State private var editingCustomLabels: Bool = false
    @State private var selectedInOption: String = ""
    @State private var selectedOutOption: String = ""
    @State private var tempInLabel: String = ""
    @State private var tempOutLabel: String = ""

    private let stageCountOptions: [Int] = {
        var values: [Int] = []
        values.append(contentsOf: 1...5)
        values.append(contentsOf: stride(from: 10, through: 50, by: 5))
        values.append(contentsOf: stride(from: 75, through: 500, by: 25))
        values.append(contentsOf: stride(from: 550, through: 1000, by: 50))
        return values
    }()
    private let kriyaTimeOptions: [Double] = {
        var values: [Double] = [0.0, 0.25]
        values.append(contentsOf: stride(from: 0.5, through: 4.0, by: 0.25))
        return values
    }()
    private let kriyaBreathInOptions: [String] = ["In", "Inhale", "Breath In", "Custom text"]
    private let kriyaBreathOutOptions: [String] = ["Out", "Exhale", "Breath out", "Custom text"]
    private var displayKriyaBreathInOptions: [String] {
        var opts = kriyaBreathInOptions
        
        // Add all unique custom labels from saved Kriyas
        let savedKriyas = getSavedKriyas()
        let customLabels = savedKriyas
            .map { $0.kriyaBreathInLabel.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !opts.contains($0) }
        
        for label in Set(customLabels).sorted() {
            opts.insert(label, at: opts.count - 1) // Insert before "Custom text"
        }
        
        // Always include current label if not already present
        let current = kriyaBreathInLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty && !opts.contains(current) {
            opts.insert(current, at: 0)
        }
        return opts
    }
    private var displayKriyaBreathOutOptions: [String] {
        var opts = kriyaBreathOutOptions
        
        // Add all unique custom labels from saved Kriyas
        let savedKriyas = getSavedKriyas()
        let customLabels = savedKriyas
            .map { $0.kriyaBreathOutLabel.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !opts.contains($0) }
        
        for label in Set(customLabels).sorted() {
            opts.insert(label, at: opts.count - 1) // Insert before "Custom text"
        }
        
        // Always include current label if not already present
        let current = kriyaBreathOutLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty && !opts.contains(current) {
            opts.insert(current, at: 0)
        }
        return opts
    }
    
    private func formatTime(_ seconds: Double) -> String {
        if seconds == 0 {
            return "0"
        }
        let formatted = String(format: "%.2f", seconds)
        // Remove trailing zeros and decimal point if needed
        let trimmed = formatted.replacingOccurrences(of: #"\\.(\\d*?)0+$"#, with: ".$1", options: .regularExpression)
        return trimmed.hasSuffix(".") ? String(trimmed.dropLast()) : trimmed
    }
    
    @AppStorage("selectedVoiceID") private var selectedVoiceID: String = ""
    @AppStorage("prepTimeSeconds") private var prepTimeSeconds: Int = 5
    @AppStorage("breathInLabel") private var breathInLabel: String = "Inhale"
    @AppStorage("breathOutLabel") private var breathOutLabel: String = "Exhale"
    @AppStorage("savedKriyas") private var savedKriyas: Data = Data()
    @AppStorage("restBetweenRoundsSeconds") private var restBetweenRoundsSeconds: Int = 0
    
    @StateObject private var session = PranayamaSessionManager()
    
    enum Phase {
        case idle, breathIn, breathOut, rest
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
                            .disabled(!inSession || inPrepPhase || phase == .rest)

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
                                        Text("Breath-in sound")
                                        Spacer()
                                        Picker("", selection: $selectedInOption) {
                                            ForEach(displayKriyaBreathInOptions, id: \.self) { option in
                                                Text(option).tag(option)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .onChange(of: selectedInOption) { _, newValue in
                                            if newValue == "Custom text" {
                                                // Reset selection to current label and open combined editor
                                                selectedInOption = kriyaBreathInLabel
                                                tempInLabel = kriyaBreathInLabel
                                                tempOutLabel = kriyaBreathOutLabel
                                                editingCustomLabels = true
                                            } else {
                                                kriyaBreathInLabel = newValue
                                            }
                                        }
                                    }
                                    HStack {
                                        Text("Breathout sound")
                                        Spacer()
                                        Picker("", selection: $selectedOutOption) {
                                            ForEach(displayKriyaBreathOutOptions, id: \.self) { option in
                                                Text(option).tag(option)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .onChange(of: selectedOutOption) { _, newValue in
                                            if newValue == "Custom text" {
                                                selectedOutOption = kriyaBreathOutLabel
                                                tempInLabel = kriyaBreathInLabel
                                                tempOutLabel = kriyaBreathOutLabel
                                                editingCustomLabels = true
                                            } else {
                                                kriyaBreathOutLabel = newValue
                                            }
                                        }
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
                                        ForEach(kriyaTimeOptions, id: \.self) { value in
                                            Button("\(formatTime(value))s") {
                                                stage.breathInSeconds = value
                                            }
                                        }
                                    } label: {
                                        Text(formatTime(stage.breathInSeconds))
                                            .font(.caption)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 8)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    Menu {
                                        ForEach(kriyaTimeOptions, id: \.self) { value in
                                            Button("\(formatTime(value))s") {
                                                stage.breathOutSeconds = value
                                            }
                                        }
                                    } label: {
                                        Text(formatTime(stage.breathOutSeconds))
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
                            Picker("Rounds", selection: $roundCount) {
                                ForEach(1...10, id: \.self) { value in
                                    Text("\(value)").tag(value)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Section {
                            Picker("Rest between rounds", selection: $restBetweenRoundsSeconds) {
                                ForEach(Array(stride(from: 0, through: 120, by: 10)), id: \.self) { value in
                                    Text("\(value) sec").tag(value)
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
            .alert("Invalid durations", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .onDisappear {
                stop()
            }
        }
            .onAppear {
                // Initialize pickers to current labels
                selectedInOption = kriyaBreathInLabel
                selectedOutOption = kriyaBreathOutLabel
            }
            .sheet(isPresented: $editingCustomLabels) {
                NavigationView {
                    Form {
                        Section(header: Text("Custom Labels")) {
                            HStack {
                                Text("Breath-in")
                                Spacer()
                                TextField("Enter custom text", text: $tempInLabel)
                                    .multilineTextAlignment(.trailing)
                            }
                            HStack {
                                Text("Breathout")
                                Spacer()
                                TextField("Enter custom text", text: $tempOutLabel)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                    .navigationTitle("Custom Text")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                editingCustomLabels = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                // Apply both labels and sync picker selections
                                kriyaBreathInLabel = tempInLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                                kriyaBreathOutLabel = tempOutLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                                selectedInOption = kriyaBreathInLabel
                                selectedOutOption = kriyaBreathOutLabel
                                editingCustomLabels = false
                            }
                        }
                    }
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
        case .rest: return Color.gray
        case .idle: return Color.gray
        }
    }
    
    private var phaseText: String {
        switch phase {
        case .idle: return "Idle"
        case .breathIn: return kriyaBreathInLabel
        case .breathOut: return kriyaBreathOutLabel
        case .rest: return "Rest"
        }
    }
    
    private func getVoiceRateForDuration(_ duration: Double) -> Float {
        // Map to iOS valid range: 0.25s->0.8 (fast), 1.0s->0.1, 2.0s+->0.0 (slowest)
        let rateMap: [Double: Float] = [
            0.0: 0.0,
            0.25: 0.8,
            0.5: 0.55,
            0.75: 0.30,
            1.0: 0.1,
            1.25: 0.07,
            1.5: 0.04,
            1.75: 0.02,
            2.0: 0.0,
            2.25: 0.0,
            2.5: 0.0,
            2.75: 0.0,
            3.0: 0.0,
            3.25: 0.0,
            3.5: 0.0,
            3.75: 0.0,
            4.0: 0.0
        ]
        
        return rateMap[duration] ?? 0.0
    }
    
    private func start() {
        guard session.state == .idle else { return }
        guard !stages.isEmpty else { return }

        // Validate at least one of in/out per stage is > 0
        if stages.contains(where: { $0.breathInSeconds <= 0 && $0.breathOutSeconds <= 0 }) {
            validationMessage = "at least one of the in and out duration should be more than zero"
            showValidationAlert = true
            return
        }
        
        // Auto-save if user provided a name
        let trimmedName = kriyaName.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            saveKriya()
        }
        
        currentStageIndex = 0
        currentStageCount = 1
        remainingRounds = roundCount - 1
        elapsed = 0
        elapsedFractional = 0.0
        isPaused = false
        inSession = true
        inPrepPhase = true
        
        AudioManager.shared.speak(message: "Prepare for breathing exercise. Take position.", voiceID: selectedVoiceID, rate: 0.5)
        
        let workItem = DispatchWorkItem {
            self.inPrepPhase = false
            self.playCurrentStage()
            
            // Start session with a finer tick interval for accurate short durations (e.g., 0.25s)
            self.session.start(tickInterval: 0.05) { timeInterval in
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
        
        // During rest, speak a prep prompt 3 seconds before next round
        if phase == .rest {
            let remaining = currentPhaseDuration - elapsedFractional
            if !restPrepPromptSpoken && restBetweenRoundsSeconds >= 3 && remaining <= 3.0 && remaining > 0 {
                restPrepPromptSpoken = true
                AudioManager.shared.speak(message: "Lets get ready for next round", voiceID: selectedVoiceID, rate: 0.5)
            }
        }
        
        // Use a small epsilon to account for floating-point rounding (e.g., 0.25s)
        if elapsedFractional + 0.00001 >= currentPhaseDuration {
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
            case .rest:
                // Rest complete; start next round (sequence of stages)
                currentStageIndex = 0
                currentStageCount = 1
                playCurrentStage()
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
        } else if remainingRounds > 0 {
            // All stages complete; insert rest between rounds if configured
            remainingRounds -= 1
            if restBetweenRoundsSeconds > 0 {
                // Speak ending prompt between rounds when rest is enabled
                AudioManager.shared.speak(message: "Relax, take few long and deep breaths", voiceID: selectedVoiceID, rate: 0.5)
                phase = .rest
                elapsed = 0
                elapsedFractional = 0.0
                restPrepPromptSpoken = false
            } else {
                currentStageIndex = 0
                currentStageCount = 1
                playCurrentStage()
            }
        } else {
            // All stages and repeats complete, show ending prompt
            phase = .idle
            session.pause()
            showingEndPrompt = true
            // Cancel any queued in/out prompts before speaking the end prompt
            AudioManager.shared.stopSpeaking()
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
        case .rest: return Double(restBetweenRoundsSeconds)
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
            roundCount: roundCount
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
        selectedInOption = kriyaBreathInLabel
        selectedOutOption = kriyaBreathOutLabel
        roundCount = kriya.roundCount
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
