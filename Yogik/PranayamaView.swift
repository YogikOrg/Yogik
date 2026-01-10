import SwiftUI
import AudioToolbox
import UIKit

struct PranayamaView: View {
    @State private var breathInRatio: Int = 4
    @State private var holdInRatio: Int = 8
    @State private var breathOutRatio: Int = 16
    @State private var holdOutRatio: Int = 0
    
    enum Pace: String, CaseIterable, Identifiable {
        case fast = "Fast"
        case medium = "Medium"
        case slow = "Slow"
        
        var id: String { rawValue }
        var multiplier: Int {
            switch self {
            case .fast: return 1
            case .medium: return 2
            case .slow: return 3
            }
        }
    }
    
    @State private var selectedPace: Pace = .fast
    @State private var isRunning: Bool = false
    @State private var remaining: Int = 0
    @State private var roundCount: Int = 0
    @State private var timer: Timer? = nil
    @State private var isPaused: Bool = false
    @State private var showingDial: Bool = false
    
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
                            Text("\(remaining) s")
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
                        
                        Section(header: Text("Pace")) {
                            Picker("Pace", selection: $selectedPace) {
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
        (breathInRatio + holdInRatio + breathOutRatio + holdOutRatio) * selectedPace.multiplier
    }
    
    private var currentPhaseTotal: Int {
        let ratio: Int
        switch phase {
        case .breathIn:
            ratio = breathInRatio
        case .holdIn:
            ratio = holdInRatio
        case .breathOut:
            ratio = breathOutRatio
        case .holdOut:
            ratio = holdOutRatio
        case .idle:
            return 1
        }
        return max(ratio * selectedPace.multiplier, 1)
    }
    
    private var progress: Double {
        let total = currentPhaseTotal
        guard total > 0 else { return 0 }
        return 1.0 - Double(remaining) / Double(total)
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
        guard !isRunning else { return }
        guard totalCycleTime > 0 else { return }
        
        addOrUpdateHistoryOnStart()
        
        roundCount = 0
        isRunning = true
        isPaused = false
        
        // Start with breathIn if it has a ratio > 0
        if breathInRatio > 0 {
            phase = .breathIn
            remaining = breathInRatio * selectedPace.multiplier
        } else {
            advanceToNextPhase()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
        
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    private func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        phase = .idle
        updateHistoryOnStop()
        remaining = 0
        roundCount = 0
        isPaused = false
        showingDial = false
        
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    private func togglePause() {
        guard isRunning else { return }
        if isPaused {
            isPaused = false
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                tick()
            }
            RunLoop.main.add(timer!, forMode: .common)
        } else {
            timer?.invalidate()
            timer = nil
            isPaused = true
        }
    }
    
    private func tick() {
        if remaining > 0 {
            // Play progress sound (Chord) every second
            playChime()
            remaining -= 1
            return
        }
        
        // Phase complete, advance
        advanceToNextPhase()
    }
    
    private func advanceToNextPhase() {
        switch phase {
        case .idle, .breathIn:
            if holdInRatio > 0 {
                phase = .holdIn
                remaining = holdInRatio * selectedPace.multiplier
                playPhaseTransitionSound()
            } else if breathOutRatio > 0 {
                phase = .breathOut
                remaining = breathOutRatio * selectedPace.multiplier
                playPhaseTransitionSound()
            } else if holdOutRatio > 0 {
                phase = .holdOut
                remaining = holdOutRatio * selectedPace.multiplier
                playPhaseTransitionSound()
            } else {
                completeRound()
            }
            
        case .holdIn:
            if breathOutRatio > 0 {
                phase = .breathOut
                remaining = breathOutRatio * selectedPace.multiplier
                playPhaseTransitionSound()
            } else if holdOutRatio > 0 {
                phase = .holdOut
                remaining = holdOutRatio * selectedPace.multiplier
                playPhaseTransitionSound()
            } else {
                completeRound()
            }
            
        case .breathOut:
            if holdOutRatio > 0 {
                phase = .holdOut
                remaining = holdOutRatio * selectedPace.multiplier
                playPhaseTransitionSound()
            } else {
                completeRound()
            }
            
        case .holdOut:
            completeRound()
        }
    }
    
    private func completeRound() {
        roundCount += 1
        playLapCompletionSound()
        // Start next round
        if breathInRatio > 0 {
            phase = .breathIn
            remaining = breathInRatio * selectedPace.multiplier
        } else {
            advanceToNextPhase()
        }
    }
    
    private func playChime() {
        // Play Chord sound (ID: 1057) every second during breathing
        AudioServicesPlaySystemSound(SystemSoundID(1057))
    }
    
    private func playPhaseTransitionSound() {
        // Play Bamboo sound (ID: 1111) when transitioning between phases
        AudioServicesPlaySystemSound(SystemSoundID(1111))
    }
    
    private func playLapCompletionSound() {
        // Play Bell sound (ID: 1115) at lap completion
        AudioServicesPlaySystemSound(SystemSoundID(1115))
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
