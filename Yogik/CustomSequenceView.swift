//
//  CustomSequenceView.swift
//  Yogik
//
//  Created by Manbhawan on 22/01/2026.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

extension UTType {
    static let yogikseq = UTType(filenameExtension: "yogikseq") ?? .data
}

struct CustomSequenceView: View {
    struct Pose: Identifiable, Codable {
        let id: UUID
        var name: String
        var transitionTime: Int
        var instruction: String
        var holdTime: Int
        var holdPrompt: String
        
        init(id: UUID = UUID(), name: String = "", transitionTime: Int = 5, instruction: String = "", holdTime: Int = 10, holdPrompt: String = "") {
            self.id = id
            self.name = name
            self.transitionTime = transitionTime
            self.instruction = instruction
            self.holdTime = holdTime
            self.holdPrompt = holdPrompt
        }
    }
    
    struct SavedSequence: Codable, Identifiable {
        let id: UUID
        let name: String
        let poses: [Pose]
        var isPreset: Bool
        
        init(id: UUID = UUID(), name: String, poses: [Pose], isPreset: Bool = false) {
            self.id = id
            self.name = name
            self.poses = poses
            self.isPreset = isPreset
        }
        
        enum CodingKeys: String, CodingKey {
            case id, name, poses, isPreset
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            poses = try container.decode([Pose].self, forKey: .poses)
            isPreset = try container.decodeIfPresent(Bool.self, forKey: .isPreset) ?? false
        }
    }
    
    struct ExportedSequence: Codable {
        let version: Int
        let sequence: SavedSequence
        
        init(sequence: SavedSequence) {
            self.version = 1
            self.sequence = sequence
        }
    }
    
    @State private var poses: [Pose] = [Pose()]
    @State private var sequenceName: String = ""
    @State private var currentPoseIndex: Int = 0
    @State private var elapsedSeconds: Double = 0
    @State private var isPaused: Bool = false
    @State private var showingDial: Bool = false
    @State private var inSession: Bool = false
    @State private var inPrepPhase: Bool = false
    @State private var showingEndPrompt: Bool = false
    @State private var prepWorkItem: DispatchWorkItem?
    @State private var showingSettings: Bool = false
    @State private var expandedPoseId: UUID?
    @State private var showingFileImporter: Bool = false
    @State private var selectedSequenceForExport: SavedSequence?
    @State private var showingShareSheet: Bool = false
    @State private var savedSequences: [SavedSequence] = []
    @State private var presetSequences: [SavedSequence] = []
    @State private var showingRoundsPrompt: Bool = false
    @State private var roundsInput: String = "1"
    @State private var totalRounds: Int = 1
    @State private var currentRound: Int = 1
    
    @AppStorage("selectedVoiceID") private var selectedVoiceID: String = ""
    @AppStorage("prepTimeSeconds") private var prepTimeSeconds: Int = 5
    @AppStorage("savedCustomSequences") private var savedSequencesData: Data = Data()
    
    @StateObject private var session = PranayamaSessionManager()
    
    enum Phase {
        case idle, transition, hold
    }
    @State private var phase: Phase = .idle
    
    // Transition times: 1s to 15s in 1s steps
    private let transitionTimeOptions: [Int] = Array(1...15)
    // Hold times: 1-10s by 1s, 15-60s by 5s, 70-120s by 10s, 150-600s by 30s (up to 10 minutes)
    private let holdTimeOptions: [Int] = {
        var values: [Int] = []
        values.append(contentsOf: 1...10)
        values.append(contentsOf: stride(from: 15, through: 60, by: 5))
        values.append(contentsOf: stride(from: 70, through: 120, by: 10))
        values.append(contentsOf: stride(from: 150, through: 600, by: 30))
        return values
    }()
    
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
                                Text("Practice complete")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 30)
                    } else {
                        // Dial UI
                        VStack(spacing: 16) {
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
                                
                                VStack(spacing: 8) {
                                    Text(phaseText)
                                        .font(.headline)
                                        .foregroundColor(phaseColor)
                                    Text("\(elapsedDisplay)")
                                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                                }
                            }
                            
                            // Show pose name and progress
                            if currentPoseIndex < poses.count {
                                Text(poses[currentPoseIndex].name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                if poses.count > 1 {
                                    Text("Pose \(currentPoseIndex + 1) / \(poses.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Show round progress
                            if totalRounds > 0 {
                                Text("Round \(currentRound) / \(totalRounds)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
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
                                Text("Sequence name")
                                Spacer()
                                TextField("Enter name", text: $sequenceName)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        
                        Section(header: Text("Poses")) {
                            ForEach(Array(poses.enumerated()), id: \.element.id) { index, pose in
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { expandedPoseId == pose.id },
                                        set: { isExpanded in
                                            expandedPoseId = isExpanded ? pose.id : nil
                                        }
                                    )
                                ) {
                                    VStack(spacing: 14) {
                                        // Pose name
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Pose name")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            TextField("e.g., Mountain Pose", text: $poses[index].name)
                                                .padding(10)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(10)
                                        }
                                        
                                        // Transition and hold times side by side
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Transition")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Picker("", selection: $poses[index].transitionTime) {
                                                    ForEach(transitionTimeOptions, id: \.self) { value in
                                                        Text("\(value)s").tag(value)
                                                    }
                                                }
                                                .pickerStyle(.menu)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(8)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(8)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Hold")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Picker("", selection: $poses[index].holdTime) {
                                                    ForEach(holdTimeOptions, id: \.self) { value in
                                                        Text("\(value)s").tag(value)
                                                    }
                                                }
                                                .pickerStyle(.menu)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(8)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(8)
                                            }
                                        }
                                        
                                        // Instruction
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Instruction")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            TextEditor(text: $poses[index].instruction)
                                                .frame(height: 70)
                                                .padding(6)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(10)
                                        }
                                        
                                        // Hold prompt
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Hold prompt")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            TextEditor(text: $poses[index].holdPrompt)
                                                .frame(height: 70)
                                                .padding(6)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(10)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemGray6).opacity(0.5))
                                    )
                                } label: {
                                    HStack {
                                        Text(pose.name.isEmpty ? "Pose \(index + 1)" : "\(index + 1): \(pose.name)")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("\(pose.transitionTime + pose.holdTime)s")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .onDelete(perform: deletePose)
                            .onMove(perform: movePose)
                            
                            Button(action: addPose) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle")
                                    Text("Add Pose")
                                }
                            }
                        }
                        
                        Section {
                            Button(action: saveSequence) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Save Sequence")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(sequenceName.trimmingCharacters(in: .whitespaces).isEmpty || poses.isEmpty || poses.allSatisfy { $0.name.isEmpty })
                        }
                        
                        if !savedSequences.isEmpty {
                            Section(header: Text("Saved Sequences")) {
                                ForEach(savedSequences, id: \.id) { saved in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Button(action: { loadSequence(saved) }) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(saved.name)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.primary)
                                                    Text("\(saved.poses.count) pose\(saved.poses.count == 1 ? "" : "s")")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            
                                            Button(action: { exportSequence(saved) }) {
                                                Image(systemName: "square.and.arrow.up")
                                                    .font(.body)
                                            }
                                            .buttonStyle(.bordered)
                                            
                                            Button(action: { 
                                                deleteSavedSequenceByID(saved.id)
                                                savedSequences.removeAll { $0.id == saved.id }
                                            }) {
                                                Image(systemName: "trash")
                                                    .font(.body)
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(.red)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        
                        if !presetSequences.isEmpty {
                            Section(header: Text("Examples to customize")) {
                                ForEach(presetSequences, id: \.id) { preset in
                                    Button(action: { loadSequenceForEditing(preset) }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(preset.name)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.primary)
                                                Text("\(preset.poses.count) pose\(preset.poses.count == 1 ? "" : "s")")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "pencil")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        
                        Section {
                            Button(action: { showingFileImporter = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Import Sequence")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    Spacer()
                }
            }
            .navigationTitle("Custom Sequence")
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
            .onAppear {
                // Load saved sequences from UserDefaults (only user sequences)
                let allSequences = getSavedSequences()
                savedSequences = allSequences.filter { !$0.isPreset }
                
                // Load preset sequences separately
                presetSequences = getPresetSequences()
                
                // Expand first pose by default if there's only one pose
                if poses.count == 1, let firstPose = poses.first {
                    expandedPoseId = firstPose.id
                }
            }
            .onDisappear {
                stop()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingRoundsPrompt) {
                VStack(spacing: 16) {
                    Text("How many rounds?")
                        .font(.headline)
                    TextField("1", text: $roundsInput)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    HStack {
                        Button("Cancel") {
                            showingRoundsPrompt = false
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button("Start") {
                            confirmRoundsAndStart()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .presentationDetents([.fraction(0.28)])
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.yogikseq, .json],
                onCompletion: { result in
                    handleFileImport(result)
                }
            )
        }
    }
    
    private var elapsedDisplay: Int { Int(elapsedSeconds) }
    
    private var progress: Double {
        guard currentPhaseDuration > 0 else { return 0 }
        return elapsedSeconds / Double(currentPhaseDuration)
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
    
    private var currentPhaseDuration: Int {
        guard currentPoseIndex < poses.count else { return 1 }
        let pose = poses[currentPoseIndex]
        switch phase {
        case .transition: return pose.transitionTime
        case .hold: return pose.holdTime
        case .idle: return 1
        }
    }
    
    private func promptStart() {
        guard session.state == .idle else { return }
        roundsInput = "1"
        showingRoundsPrompt = true
    }
    
    private func confirmRoundsAndStart() {
        showingRoundsPrompt = false
        let rounds = Int(roundsInput) ?? 1
        totalRounds = max(1, rounds)
        currentRound = 1
        startSession()
    }
    
    private func startSession() {
        guard session.state == .idle else { return }
        guard !poses.isEmpty else { return }
        
        currentPoseIndex = 0
        elapsedSeconds = 0
        isPaused = false
        inSession = true
        inPrepPhase = true
        
        AudioManager.shared.speak(message: "Prepare for your practice. Take position.", voiceID: selectedVoiceID, rate: 0.35)
        
        let workItem = DispatchWorkItem {
            self.inPrepPhase = false
            self.playCurrentPose()
            
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
        elapsedSeconds = 0
        isPaused = false
        showingDial = false
        showingEndPrompt = false
        inSession = false
        inPrepPhase = false
        currentPoseIndex = 0
        totalRounds = 1
        currentRound = 1
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
        elapsedSeconds += timeInterval
        
        if elapsedSeconds >= Double(currentPhaseDuration) {
            // Phase complete, move to next
            switch phase {
            case .transition:
                // Move to hold phase
                phase = .hold
                elapsedSeconds = 0
                let pose = poses[currentPoseIndex]
                // Speak hold instruction followed by user hold prompt
                AudioManager.shared.speak(message: "Hold the position", voiceID: selectedVoiceID, rate: 0.35)
                if !pose.holdPrompt.isEmpty {
                    AudioManager.shared.speak(message: pose.holdPrompt, voiceID: selectedVoiceID, rate: 0.35)
                }
            case .hold:
                // Move to next pose
                moveToNextPose()
            case .idle:
                stop()
            }
        }
    }
    
    private func moveToNextPose() {
        if currentPoseIndex < poses.count - 1 {
            // Move to next pose
            currentPoseIndex += 1
            playCurrentPose()
        } else if currentRound < totalRounds {
            // Next round
            currentRound += 1
            // Check if first and last pose have the same name
            let shouldSkipFirstPose = poses.count > 1 && 
                                     poses[0].name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == 
                                     poses[poses.count - 1].name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() &&
                                     !poses[0].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            currentPoseIndex = shouldSkipFirstPose ? 1 : 0
            playCurrentPose()
        } else {
            // All rounds complete
            phase = .idle
            session.pause()
            showingEndPrompt = true
            AudioManager.shared.stopSpeaking()
            AudioManager.shared.speak(message: "Practice complete. Well done.", voiceID: selectedVoiceID, rate: 0.35)
        }
    }
    
    private func playCurrentPose() {
        let pose = poses[currentPoseIndex]
        phase = .transition
        elapsedSeconds = 0
        
        // Speak pose name first, then instruction
        AudioManager.shared.speak(message: pose.name, voiceID: selectedVoiceID, rate: 0.35)
        
        if !pose.instruction.isEmpty {
            AudioManager.shared.speak(message: pose.instruction, voiceID: selectedVoiceID, rate: 0.35)
        }
    }
    
    private func addPose() {
        // Collapse current expanded pose
        expandedPoseId = nil
        
        // Add new pose, prefilled from last pose if available
        let newPose: Pose
        if let last = poses.last {
            newPose = Pose(name: last.name, transitionTime: last.transitionTime, instruction: last.instruction, holdTime: last.holdTime, holdPrompt: last.holdPrompt)
        } else {
            newPose = Pose()
        }
        poses.append(newPose)
        
        // Expand the newly added pose
        expandedPoseId = newPose.id
    }
    
    private func deletePose(at offsets: IndexSet) {
        poses.remove(atOffsets: offsets)
    }
    
    private func movePose(from source: IndexSet, to destination: Int) {
        poses.move(fromOffsets: source, toOffset: destination)
    }
    
    private func getSavedSequences() -> [SavedSequence] {
        guard let data = UserDefaults.standard.data(forKey: "savedCustomSequences") else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([SavedSequence].self, from: data)) ?? []
    }
    
    private func saveSequence() {
        let trimmedName = sequenceName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !poses.isEmpty else { return }
        
        var allSequences = getSavedSequences()
        let newSequence = SavedSequence(name: trimmedName, poses: poses)
        allSequences.append(newSequence)
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(allSequences) {
            UserDefaults.standard.set(encoded, forKey: "savedCustomSequences")
            savedSequences = allSequences
            sequenceName = ""
        }
    }
    
    private func loadSequence(_ sequence: SavedSequence) {
        poses = sequence.poses
        sequenceName = ""
        showingDial = false
        inSession = false
        promptStart()
    }
    
    private func loadSequenceForEditing(_ sequence: SavedSequence) {
        poses = sequence.poses
        sequenceName = ""
        showingDial = false
        inSession = false
        // Don't start - just load for editing
    }
    
    private func deleteSavedSequence(at offsets: IndexSet) {
        var allSequences = getSavedSequences()
        allSequences.remove(atOffsets: offsets)
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(allSequences) {
            UserDefaults.standard.set(encoded, forKey: "savedCustomSequences")
        }
    }
    
    private func deleteSavedSequenceByID(_ id: UUID) {
        var allSequences = getSavedSequences()
        allSequences.removeAll { $0.id == id }
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(allSequences) {
            UserDefaults.standard.set(encoded, forKey: "savedCustomSequences")
        }
    }
    
    private func exportSequence(_ sequence: SavedSequence) {
        let exported = ExportedSequence(sequence: sequence)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let jsonData = try? encoder.encode(exported) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        // Save to temporary file
        let fileName = "\(sequence.name.replacingOccurrences(of: " ", with: "_")).yogikseq"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try jsonString.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Present share sheet
            let shareVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .first?
                .rootViewController?
                .present(shareVC, animated: true)
        } catch {
            // Handle error silently
        }
    }
    
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            do {
                // Read the file
                let data = try Data(contentsOf: url)
                
                // Decode the exported sequence
                let decoder = JSONDecoder()
                let exported = try decoder.decode(ExportedSequence.self, from: data)
                
                // Add to saved sequences
                var allSequences = getSavedSequences()
                allSequences.append(exported.sequence)
                
                let encoder = JSONEncoder()
                if let encoded = try? encoder.encode(allSequences) {
                    UserDefaults.standard.set(encoded, forKey: "savedCustomSequences")
                    savedSequences = allSequences.filter { !$0.isPreset }
                }
            } catch {
                // Handle error silently
                print("Import error: \(error)")
            }
        case .failure(let error):
            // Handle error
            print("File picker error: \(error)")
        }
    }
    
    private func getPresetSequences() -> [SavedSequence] {
        let presetName = "Sun Salutation (Surya Namaskar)"
        
        // Create Surya Namaskar preset sequence - always regenerated with latest version
        let poses: [Pose] = [
            Pose(name: "Prayer Pose", transitionTime: 5, instruction: "Stand upright and bring your hands to heart center in prayer position.", holdTime: 10, holdPrompt: "Feel the ground beneath your feet. Center yourself. Keep breathing."),
            Pose(name: "Raised Arms Pose", transitionTime: 5, instruction: "Inhale and raise your arms above your head, arching slightly backward.", holdTime: 10, holdPrompt: "Feel the stretch through your entire body. Keep breathing."),
            Pose(name: "Forward Fold", transitionTime: 5, instruction: "Exhale and fold forward, letting your head and arms hang heavy.", holdTime: 10, holdPrompt: "Relax your neck and shoulders. Keep breathing."),
            Pose(name: "Low Lunge Right", transitionTime: 5, instruction: "Inhale and step your right foot back into a low lunge, dropping your back knee. Stretch and look up.", holdTime: 10, holdPrompt: "Keep your front knee aligned over your ankle. Keep breathing."),
            Pose(name: "Plank", transitionTime: 5, instruction: "Step back to a plank position, shoulders over wrists, body in a straight line.", holdTime: 10, holdPrompt: "Engage your core and keep your body aligned. Keep breathing."),
            Pose(name: "Eight Limbed Pose", transitionTime: 5, instruction: "Exhale and lower your body so that your hands, feet, knees, chest, and forehead touch the ground.", holdTime: 10, holdPrompt: "This pose combines strength and surrender. Keep breathing."),
            Pose(name: "Cobra Pose", transitionTime: 5, instruction: "Inhale and roll forward, pressing your chest up with your hands while keeping hips down. Stretch and look up.", holdTime: 10, holdPrompt: "Open your chest, lengthen your spine. Keep breathing."),
            Pose(name: "Downward Facing Dog", transitionTime: 5, instruction: "Exhale and push back into downward dog, forming an inverted V-shape.", holdTime: 10, holdPrompt: "Press firmly through your hands, relax your head. Keep breathing."),
            Pose(name: "Low Lunge Right Forward", transitionTime: 5, instruction: "Inhale and step your right foot forward into a low lunge. Stretch and look up.", holdTime: 10, holdPrompt: "Keep your front knee aligned over your ankle. Keep breathing."),
            Pose(name: "Forward Fold", transitionTime: 5, instruction: "Exhale, step forward and fold, letting your upper body hang.", holdTime: 10, holdPrompt: "Breathe deeply and let tension melt away. Keep breathing."),
            Pose(name: "Raised Arms Pose", transitionTime: 5, instruction: "Inhale and sweep your arms up, arching gently backward.", holdTime: 10, holdPrompt: "Expand your chest and embrace the moment. Keep breathing."),
            Pose(name: "Prayer Pose", transitionTime: 5, instruction: "Exhale and return to standing, hands at heart center.", holdTime: 10, holdPrompt: "Complete half of Surya Namaskar. Keep breathing."),
            Pose(name: "Raised Arms Pose", transitionTime: 5, instruction: "Inhale and raise your arms above your head, arching slightly backward.", holdTime: 10, holdPrompt: "Feel the stretch through your entire body. Keep breathing."),
            Pose(name: "Forward Fold", transitionTime: 5, instruction: "Exhale and fold forward, letting your head and arms hang heavy.", holdTime: 10, holdPrompt: "Relax your neck and shoulders. Keep breathing."),
            Pose(name: "Low Lunge Left", transitionTime: 5, instruction: "Inhale and step your left foot back into a low lunge, dropping your back knee. Stretch and look up.", holdTime: 10, holdPrompt: "Keep your front knee aligned over your ankle. Keep breathing."),
            Pose(name: "Plank", transitionTime: 5, instruction: "Step back to a plank position, shoulders over wrists, body in a straight line.", holdTime: 10, holdPrompt: "Engage your core and keep your body aligned. Keep breathing."),
            Pose(name: "Eight Limbed Pose", transitionTime: 5, instruction: "Exhale and lower your body so that your hands, feet, knees, chest, and forehead touch the ground.", holdTime: 10, holdPrompt: "This pose combines strength and surrender. Keep breathing."),
            Pose(name: "Cobra Pose", transitionTime: 5, instruction: "Inhale and roll forward, pressing your chest up with your hands while keeping hips down. Stretch and look up.", holdTime: 10, holdPrompt: "Open your chest, lengthen your spine. Keep breathing."),
            Pose(name: "Downward Facing Dog", transitionTime: 5, instruction: "Exhale and push back into downward dog, forming an inverted V-shape.", holdTime: 10, holdPrompt: "Press firmly through your hands, relax your head. Keep breathing."),
            Pose(name: "Low Lunge Left Forward", transitionTime: 5, instruction: "Inhale and step your left foot forward into a low lunge. Stretch and look up.", holdTime: 10, holdPrompt: "Keep your front knee aligned over your ankle. Keep breathing."),
            Pose(name: "Forward Fold", transitionTime: 5, instruction: "Exhale, step forward and fold, letting your upper body hang.", holdTime: 10, holdPrompt: "Breathe deeply and let tension melt away. Keep breathing."),
            Pose(name: "Raised Arms Pose", transitionTime: 5, instruction: "Inhale and sweep your arms up, arching gently backward.", holdTime: 10, holdPrompt: "Expand your chest and embrace the moment. Keep breathing."),
            Pose(name: "Prayer Pose", transitionTime: 5, instruction: "Exhale and return to standing, hands at heart center.", holdTime: 10, holdPrompt: "Complete one full cycle of Surya Namaskar. Keep breathing.")
        ]
        
        let presetSequence = SavedSequence(name: presetName, poses: poses, isPreset: true)
        return [presetSequence]
    }
}

#Preview {
    CustomSequenceView()
}