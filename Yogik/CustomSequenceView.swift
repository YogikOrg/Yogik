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
        
        init(id: UUID = UUID(), name: String = "", transitionTime: Int = 5, instruction: String = "", holdTime: Int = 30, holdPrompt: String = "") {
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
        
        init(id: UUID = UUID(), name: String, poses: [Pose]) {
            self.id = id
            self.name = name
            self.poses = poses
        }
    }
    
    struct ExportedSequence: Codable {
        let version: Int = 1
        let sequence: SavedSequence
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
                                    VStack(spacing: 12) {
                                        TextField("Pose name", text: $poses[index].name)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                        
                                        HStack {
                                            Text("Transition time")
                                            Spacer()
                                            Picker("", selection: $poses[index].transitionTime) {
                                                ForEach(transitionTimeOptions, id: \.self) { value in
                                                    Text("\(value)s").tag(value)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Instruction")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            TextEditor(text: $poses[index].instruction)
                                                .frame(height: 60)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                )
                                        }
                                        
                                        HStack {
                                            Text("Hold time")
                                            Spacer()
                                            Picker("", selection: $poses[index].holdTime) {
                                                ForEach(holdTimeOptions, id: \.self) { value in
                                                    Text("\(value)s").tag(value)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Hold prompt")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            TextEditor(text: $poses[index].holdPrompt)
                                                .frame(height: 60)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                )
                                        }
                                    }
                                    .padding(.vertical, 8)
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
                // Load saved sequences from UserDefaults
                savedSequences = getSavedSequences()
                
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
    
    private func start() {
        guard session.state == .idle else { return }
        guard !poses.isEmpty else { return }
        
        currentPoseIndex = 0
        elapsedSeconds = 0
        isPaused = false
        inSession = true
        inPrepPhase = true
        
        AudioManager.shared.speak(message: "Prepare for your practice. Take position.", voiceID: selectedVoiceID, rate: 0.4)
        
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
                AudioManager.shared.speak(message: "Hold the position", voiceID: selectedVoiceID, rate: 0.4)
                if !pose.holdPrompt.isEmpty {
                    AudioManager.shared.speak(message: pose.holdPrompt, voiceID: selectedVoiceID, rate: 0.4)
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
        } else {
            // All poses complete
            phase = .idle
            session.pause()
            showingEndPrompt = true
            AudioManager.shared.stopSpeaking()
            AudioManager.shared.speak(message: "Practice complete. Well done.", voiceID: selectedVoiceID, rate: 0.4)
        }
    }
    
    private func playCurrentPose() {
        let pose = poses[currentPoseIndex]
        phase = .transition
        elapsedSeconds = 0
        
        // Speak instruction
        if !pose.instruction.isEmpty {
            AudioManager.shared.speak(message: pose.instruction, voiceID: selectedVoiceID, rate: 0.4)
        } else {
            AudioManager.shared.speak(message: pose.name, voiceID: selectedVoiceID, rate: 0.4)
        }
    }
    
    private func addPose() {
        // Collapse current expanded pose
        expandedPoseId = nil
        
        // Add new pose
        let newPose = Pose()
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
        start()
        showingDial = true
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
                    savedSequences = allSequences
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
}

#Preview {
    CustomSequenceView()
}
