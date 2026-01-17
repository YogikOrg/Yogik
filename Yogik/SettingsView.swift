import SwiftUI
import AVFoundation

struct SettingsView: View {
    @AppStorage("selectedVoiceID") private var selectedVoiceID: String = ""
    @AppStorage("prepTimeSeconds") private var prepTimeSeconds: Int = 5
    @AppStorage("pranayamaProgressSoundEnabled") private var pranayamaProgressSoundEnabled: Bool = true
    @AppStorage("breathInLabel") private var breathInLabel: String = "Inhale"
    @AppStorage("breathOutLabel") private var breathOutLabel: String = "Exhale"
    @Environment(\.dismiss) private var dismiss
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []

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
                
                Section(header: Text("Pranayama")) {
                    Toggle("Progress Sound", isOn: $pranayamaProgressSoundEnabled)
                    HStack {
                        Text("Breath-in text")
                        Spacer()
                        TextField("", text: $breathInLabel)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Breathout text")
                        Spacer()
                        TextField("", text: $breathOutLabel)
                            .multilineTextAlignment(.trailing)
                    }
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
            
            // Filter for English voices only
            availableVoices = allVoices.filter { voice in
                let name = voice.name
                let isExcluded = excludedNames.contains(where: { name.contains($0) })
                
                // Include only English voices
                let isEnglish = voice.language.hasPrefix("en")
                
                guard isEnglish && !isExcluded && !seenNames.contains(name) else { return false }
                seenNames.insert(name)
                return true
            }.sorted { ($0.name) < ($1.name) }
            
            if selectedVoiceID.isEmpty && !availableVoices.isEmpty {
                // Try to find Samantha first as default, then fallback to others
                if let samantha = availableVoices.first(where: { $0.name.contains("Samantha") }) {
                    selectedVoiceID = samantha.identifier
                } else if let karen = availableVoices.first(where: { $0.name.contains("Karen") }) {
                    selectedVoiceID = karen.identifier
                } else if let moira = availableVoices.first(where: { $0.name.contains("Moira") }) {
                    selectedVoiceID = moira.identifier
                } else if let soumya = availableVoices.first(where: { $0.name.contains("Soumya") }) {
                    selectedVoiceID = soumya.identifier
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


}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
