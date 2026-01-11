import SwiftUI
import AudioToolbox
import AVFoundation

struct SettingsView: View {
    @AppStorage("progressSoundID") private var progressSoundID: Int = 1057
    @AppStorage("selectedVoiceID") private var selectedVoiceID: String = ""
    @AppStorage("prepTimeSeconds") private var prepTimeSeconds: Int = 5
    @AppStorage("pranayamaProgressSoundEnabled") private var pranayamaProgressSoundEnabled: Bool = true
    @Environment(\.dismiss) private var dismiss
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []

    private let systemChimeOptions: [(id: Int, name: String)] = [
        (0, "None"),
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

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Voice for Prompts")) {
                    Picker("Voice", selection: $selectedVoiceID) {
                        ForEach(availableVoices, id: \.identifier) { voice in
                            Text(voice.name).tag(voice.identifier)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedVoiceID) { oldValue, newValue in
                        testVoicePrompt()
                    }
                }
                
                Section(header: Text("Prep Time")) {
                    Stepper("Prep Time: \(prepTimeSeconds)s", value: $prepTimeSeconds, in: 1...60)
                }
                
                Section(header: Text("Progress Sound")) {
                    Picker("Progress Sound", selection: $progressSoundID) {
                        ForEach(systemChimeOptions, id: \.id) { option in
                            Text(option.name).tag(option.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: progressSoundID) { oldValue, newValue in
                        playChime(soundID: newValue)
                    }
                }
                
                Section(header: Text("Pranayama Progress Sound")) {
                    Toggle("Play sound every count", isOn: $pranayamaProgressSoundEnabled)
                }

                Section {
                    Button("Done") { dismiss() }
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            let allVoices = AVSpeechSynthesisVoice.speechVoices()
            var seenNames = Set<String>()
            
            // Exclude novelty/character voices
            let excludedNames = ["Albert", "Bad News", "Bahh", "Bells", "Boing", "Bubbles", "Cellos", "Eddy", "Flo", "Fred", "Good News", "Jester", "Organ", "Ralph", "Reed", "Rocko", "Sandy", "Shelley", "Trinoids", "Whisper", "Wobble", "Zarvox", "Junior", "Kathy"]
            
            // Filter for English, Hindi, and other Indian language voices
            availableVoices = allVoices.filter { voice in
                let name = voice.name
                let isExcluded = excludedNames.contains(where: { name.contains($0) })
                
                // Include English, Hindi (hi-IN), and other Indian voices
                let isEnglish = voice.language.hasPrefix("en")
                let isHindi = voice.language.hasPrefix("hi")
                let isIndian = voice.language.hasSuffix("-IN")
                
                guard (isEnglish || isHindi || isIndian) && !isExcluded && !seenNames.contains(name) else { return false }
                seenNames.insert(name)
                return true
            }.sorted { ($0.name) < ($1.name) }
            
            if selectedVoiceID.isEmpty && !availableVoices.isEmpty {
                // Try to find Moira first, then Soumya, then Karen, then Samantha, then default
                if let moira = availableVoices.first(where: { $0.name.contains("Moira") }) {
                    selectedVoiceID = moira.identifier
                } else if let soumya = availableVoices.first(where: { $0.name.contains("Soumya") }) {
                    selectedVoiceID = soumya.identifier
                } else if let karen = availableVoices.first(where: { $0.name.contains("Karen") }) {
                    selectedVoiceID = karen.identifier
                } else if let samantha = availableVoices.first(where: { $0.name.contains("Samantha") }) {
                    selectedVoiceID = samantha.identifier
                } else {
                    selectedVoiceID = availableVoices[0].identifier
                }
            }
        }
    }
    
    private func testVoicePrompt() {
        let utterance = AVSpeechUtterance(string: "Inhale")
        if let voice = AVSpeechSynthesisVoice(identifier: selectedVoiceID) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }

    private func playChime(soundID: Int) {
        guard soundID != 0 else { return }
        AudioServicesPlaySystemSound(SystemSoundID(soundID))
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
