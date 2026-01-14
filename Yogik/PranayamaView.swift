import SwiftUI

struct PranayamaView: View {
    @State private var breathInRatio: Int = 4
    @State private var holdInRatio: Int = 4
    @State private var breathOutRatio: Int = 6
    @State private var holdOutRatio: Int = 2
    
    enum Pace: String, CaseIterable, Identifiable {
        case fast = "Fast (1s)"
        case medium = "Medium (1.5s)"
        case slow = "Slow (2s)"
        
        var id: String { rawValue }
        var multiplier: Double {
            switch self {
            case .fast: return 1.0
            case .medium: return 1.5
            case .slow: return 2.0
            }
        }
    }
    
    @State private var selectedPace: Pace = .fast
    @State private var remaining: Int = 0
    @State private var elapsed: Int = 0
    @State private var roundCount: Int = 0
    @State private var isPaused: Bool = false
    @State private var showingDial: Bool = false
    @State private var countElapsed: Double = 0
    @State private var inSession: Bool = false
    @State private var inPrepPhase: Bool = false
    @State private var prepWorkItem: DispatchWorkItem?
    @AppStorage("selectedVoiceID") private var selectedVoiceID: String = ""
    @AppStorage("prepTimeSeconds") private var prepTimeSeconds: Int = 5
    @AppStorage("pranayamaProgressSoundEnabled") private var pranayamaProgressSoundEnabled: Bool = true

    
    @StateObject private var session = PranayamaSessionManager()
    
    var isRunning: Bool {
        session.isRunning
    }
    
    enum BreathPhase {
        case idle, breathIn, holdIn, breathOut, holdOut
    }
    @State private var phase: BreathPhase = .idle
    
    enum PickerSelection: String, Identifiable {
        case breathIn, holdIn, breathOut, holdOut
        var id: String { rawValue }
    }
    @State private var activePicker: PickerSelection? = nil
    
    // History persistence
    struct TimerSetup: Identifiable, Codable, Equatable {
        let id: UUID
        var breathInRatio: Int
        var holdInRatio: Int
        var breathOutRatio: Int
        var holdOutRatio: Int
        var pace: String
        var date: Date
        var rounds: Int
        
        var name: String {
            "\(breathInRatio):\(holdInRatio):\(breathOutRatio):\(holdOutRatio)"
        }
    }
    
    @State private var history: [TimerSetup] = []
    private let historyKey = "Yogik.pranayamaHistory"
    @State private var showingSettings: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if showingDial {
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
                            Text("Rounds: \(roundCount)")
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

                        Button(action: stop) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!inSession)
                    }
                    .padding()
                    Spacer()
                } else {
                    // Setup UI
                    Form {
                        Section(header: Text("Breath Ratio (In : Hold : Out : Hold)")) {
                            HStack(spacing: 8) {
                                Button(action: {
                                    guard !isRunning else { return }
                                    activePicker = .breathIn
                                }) {
                                    Text("\(breathInRatio)")
                                        .frame(minWidth: 40)
                                        .padding(.vertical, 8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .disabled(isRunning)
                                
                                Text(":")
                                
                                Button(action: {
                                    guard !isRunning else { return }
                                    activePicker = .holdIn
                                }) {
                                    Text("\(holdInRatio)")
                                        .frame(minWidth: 40)
                                        .padding(.vertical, 8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .disabled(isRunning)
                                
                                Text(":")
                                
                                Button(action: {
                                    guard !isRunning else { return }
                                    activePicker = .breathOut
                                }) {
                                    Text("\(breathOutRatio)")
                                        .frame(minWidth: 40)
                                        .padding(.vertical, 8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .disabled(isRunning)
                                
                                Text(":")
                                
                                Button(action: {
                                    guard !isRunning else { return }
                                    activePicker = .holdOut
                                }) {
                                    Text("\(holdOutRatio)")
                                        .frame(minWidth: 40)
                                        .padding(.vertical, 8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .disabled(isRunning)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Section(header: Text("Pace (Count duration)")) {
                            Picker("Pace (Count duration)", selection: $selectedPace) {
                                ForEach(Pace.allCases) { pace in
                                    Text(pace.rawValue).tag(pace)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .disabled(isRunning)
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
                            .disabled(isRunning || totalCycleTime == 0)
                        }
                        
                        Section(header: Text("Saved timers")) {
                            if history.isEmpty {
                                Text("No saved timers yet")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(history) { item in
                                    Button(action: {
                                        breathInRatio = item.breathInRatio
                                        holdInRatio = item.holdInRatio
                                        breathOutRatio = item.breathOutRatio
                                        holdOutRatio = item.holdOutRatio
                                        selectedPace = Pace(rawValue: item.pace) ?? .fast
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
                                                Text("\(item.rounds) rounds")
                                                    .font(.subheadline)
                                                Text(item.pace)
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
            .navigationTitle("Pranayama")
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
                        Picker(pickerTitle(for: selection), selection: bindingFor(selection)) {
                            ForEach(0...20, id: \.self) { i in
                                Text("\(i)").tag(i)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .labelsHidden()
                        .frame(maxHeight: 260)
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
                    .navigationTitle(pickerTitle(for: selection))
                }
            }
            .onAppear {
                loadHistory()
            }
        }
    }
    
    private var totalCycleTime: Int {
        // Total counts in a full cycle (without pace multiplier, pace affects timing not counts)
        breathInRatio + holdInRatio + breathOutRatio + holdOutRatio
    }
    
    private var progress: Double {
        // Progress based on count within current phase
        // remaining is the count, countElapsed is the fractional progress within that count
        guard remaining > 0 else { return 1.0 }
        let timePerCount = selectedPace.multiplier
        let progress = 1.0 - (Double(remaining - 1) + countElapsed / timePerCount) / Double(currentPhaseRatio)
        return min(max(progress, 0), 1.0)
    }
    
    private var currentPhaseRatio: Int {
        switch phase {
        case .breathIn: return breathInRatio
        case .holdIn: return holdInRatio
        case .breathOut: return breathOutRatio
        case .holdOut: return holdOutRatio
        case .idle: return 1
        }
    }
    
    private var phaseColor: Color {
        switch phase {
        case .breathIn: return Color.green
        case .holdIn: return Color.blue
        case .breathOut: return Color.orange
        case .holdOut: return Color.purple
        case .idle: return Color.gray
        }
    }
    
    private var phaseText: String {
        switch phase {
        case .idle: return "Idle"
        case .breathIn: return "Breathe In"
        case .holdIn: return "Hold"
        case .breathOut: return "Breathe Out"
        case .holdOut: return "Hold"
        }
    }
    
    private func pickerTitle(for selection: PickerSelection) -> String {
        switch selection {
        case .breathIn: return "Breath In Ratio"
        case .holdIn: return "Hold In Ratio"
        case .breathOut: return "Breath Out Ratio"
        case .holdOut: return "Hold Out Ratio"
        }
    }
    
    private func bindingFor(_ selection: PickerSelection) -> Binding<Int> {
        switch selection {
        case .breathIn: return $breathInRatio
        case .holdIn: return $holdInRatio
        case .breathOut: return $breathOutRatio
        case .holdOut: return $holdOutRatio
        }
    }
    
    private func start() {
        guard session.state == .idle else { return }
        guard totalCycleTime > 0 else { return }
        
        addOrUpdateHistoryOnStart()
        
        roundCount = 0
        isPaused = false
        countElapsed = 0
        elapsed = 1
        inSession = true
        inPrepPhase = true
        
        // Play prep prompt
        AudioManager.shared.speak(message: "Prepare for breathing exercise. Take position.", voiceID: selectedVoiceID, rate: 0.5)
        
        // Delay timer start to allow prep time before first inhale prompt
        let workItem = DispatchWorkItem {
            self.inPrepPhase = false
            // Start with breathIn if it has a ratio > 0
            if self.breathInRatio > 0 {
                self.phase = .breathIn
                self.remaining = self.breathInRatio
                self.countElapsed = 0
                self.speakPhasePrompt(.breathIn)
            } else {
                self.advanceToNextPhase()
            }
            
            // Start session with 0.1s tick interval
            let timePerCount = self.selectedPace.multiplier
            self.session.start { elapsed in
                self.tick(timePerCount: timePerCount)
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
        remaining = 0
        elapsed = 1
        roundCount = 0
        isPaused = false
        showingDial = false
        countElapsed = 0
        inSession = false
        inPrepPhase = false
        updateHistoryOnStop()
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
    
    private func tick(timePerCount: Double) {
        countElapsed += 0.1
        
        // Check if a full count has elapsed
        if countElapsed >= timePerCount {
            countElapsed = 0
            remaining -= 1
            elapsed += 1
            
            // Announce the count starting from 2 (phase prompt was spoken at 1)
            if pranayamaProgressSoundEnabled && elapsed > 1 && elapsed <= currentPhaseRatio {
                let count = String(elapsed)
                AudioManager.shared.speak(message: count, voiceID: selectedVoiceID, rate: 0.5)
            }
            
            if remaining <= 0 {
                // Phase complete, advance to next
                advanceToNextPhase()
            }
        }
    }
    
    private func advanceToNextPhase() {
        countElapsed = 0  // Reset elapsed time for new phase
        elapsed = 1  // Reset count to 1 for new phase
        
        switch phase {
        case .idle, .breathIn:
            if holdInRatio > 0 {
                phase = .holdIn
                remaining = holdInRatio
                speakPhasePrompt(.holdIn)
            } else if breathOutRatio > 0 {
                phase = .breathOut
                remaining = breathOutRatio
                speakPhasePrompt(.breathOut)
            } else if holdOutRatio > 0 {
                phase = .holdOut
                remaining = holdOutRatio
                speakPhasePrompt(.holdOut)
            } else {
                // No more phases, complete the round
                completeRound()
            }
            
        case .holdIn:
            if breathOutRatio > 0 {
                phase = .breathOut
                remaining = breathOutRatio
                speakPhasePrompt(.breathOut)
            } else if holdOutRatio > 0 {
                phase = .holdOut
                remaining = holdOutRatio
                speakPhasePrompt(.holdOut)
            } else {
                // No more phases, complete the round
                completeRound()
            }
            
        case .breathOut:
            if holdOutRatio > 0 {
                phase = .holdOut
                remaining = holdOutRatio
                speakPhasePrompt(.holdOut)
            } else {
                // No holdOut phase, complete the round here
                completeRound()
            }
            
        case .holdOut:
            // After holdOut, the full cycle is complete - increment round
            completeRound()
        }
    }
    
    private func completeRound() {
        countElapsed = 0  // Reset elapsed time for new round
        elapsed = 1  // Reset count to 1 for new round
        roundCount += 1
        // Start next round
        if breathInRatio > 0 {
            phase = .breathIn
            remaining = breathInRatio
            speakPhasePrompt(.breathIn)
        } else {
            advanceToNextPhase()
        }
    }
    

    
    private func speakPrepPrompt() {
        AudioManager.shared.speak(message: "Prepare for the breathing exercise. Take position", voiceID: selectedVoiceID)
    }
    
    private func speakPhasePrompt(_ phase: BreathPhase) {
        let message: String
        
        switch phase {
        case .breathIn:
            message = "Inhale"
        case .holdIn:
            message = "Hold"
        case .breathOut:
            message = "Exhale"
        case .holdOut:
            message = "Hold"
        case .idle:
            return
        }
        
        AudioManager.shared.speak(message: message, voiceID: selectedVoiceID)
    }
    
    // MARK: - History Functions
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
        let now = Date()
        if let idx = history.firstIndex(where: {
            $0.breathInRatio == breathInRatio &&
            $0.holdInRatio == holdInRatio &&
            $0.breathOutRatio == breathOutRatio &&
            $0.holdOutRatio == holdOutRatio &&
            $0.pace == selectedPace.rawValue
        }) {
            var e = history.remove(at: idx)
            e.date = now
            e.rounds = 0
            history.insert(e, at: 0)
        } else {
            let entry = TimerSetup(
                id: UUID(),
                breathInRatio: breathInRatio,
                holdInRatio: holdInRatio,
                breathOutRatio: breathOutRatio,
                holdOutRatio: holdOutRatio,
                pace: selectedPace.rawValue,
                date: now,
                rounds: 0
            )
            history.insert(entry, at: 0)
            if history.count > 5 {
                history.removeLast()
            }
        }
        saveHistory()
    }
    
    private func updateHistoryOnStop() {
        if let idx = history.firstIndex(where: {
            $0.breathInRatio == breathInRatio &&
            $0.holdInRatio == holdInRatio &&
            $0.breathOutRatio == breathOutRatio &&
            $0.holdOutRatio == holdOutRatio &&
            $0.pace == selectedPace.rawValue
        }) {
            history[idx].rounds = roundCount
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

struct PranayamaView_Previews: PreviewProvider {
    static var previews: some View {
        PranayamaView()
    }
}
