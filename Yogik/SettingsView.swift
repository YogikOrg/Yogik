import SwiftUI
import AudioToolbox

struct SettingsView: View {
    @AppStorage("progressSoundID") private var progressSoundID: Int = 1057
    @AppStorage("poseEndChimeID") private var poseEndChimeID: Int = 1115
    @Environment(\.dismiss) private var dismiss

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
                Section(header: Text("Progress Sound (beats during hold)")) {
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

                Section(header: Text("Pose End Chime (end of lap)")) {
                    Picker("Pose End Chime", selection: $poseEndChimeID) {
                        ForEach(systemChimeOptions, id: \.id) { option in
                            Text(option.name).tag(option.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: poseEndChimeID) { oldValue, newValue in
                        playChime(soundID: newValue)
                    }
                }

                Section {
                    Button("Done") { dismiss() }
                }
            }
            .navigationTitle("Settings")
        }
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
