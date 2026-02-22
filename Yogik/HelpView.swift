//
//  HelpView.swift
//  Yogik
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                gettingStartedSection
                yogaSection
                pranayamaSection
                kriyaSection
                customSection
                settingsSection
            }
            .navigationTitle("Getting Started")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: – Sections

    private var gettingStartedSection: some View {
        Section {
            HelpRow(icon: "hand.wave", color: .orange,
                    title: "About Yogik",
                    description: "Yogik is a practice aid for those who have already learnt Yoga, Pranayama, or Kriya. It guides your sessions with voice prompts and visual timers — it does not teach techniques. If you are new to these practices, please learn from a qualified teacher first.")
            HelpRow(icon: "speaker.wave.2", color: .blue,
                    title: "Voice Guidance",
                    description: "Yogik speaks cues aloud during every session. Audio plays even when your device is on silent.")
            HelpRow(icon: "iphone", color: .gray,
                    title: "Screen Stays On",
                    description: "The display stays on automatically during an active session so you never have to unlock your device mid-practice.")
        } header: {
            Text("")
        }
    }

    private var yogaSection: some View {
        Section {
            HelpRow(icon: "figure.cooldown", color: .green,
                    title: "Yoga Sequence",
                    description: "Set a Transition time (moving into a pose) and a Hold time (staying in the pose). Choose how many laps to complete, or set laps to 0 for a never-ending session. Tap Start and follow the voice cues.")
            HelpRow(icon: "clock.arrow.circlepath", color: .green,
                    title: "Saved Timers",
                    description: "Your last five timer configurations are saved automatically. Tap any saved timer to restore those settings instantly.")
            HelpRow(icon: "pause.circle", color: .green,
                    title: "Pausing & Stopping",
                    description: "Tap the Pause button to hold the session. Tap Stop to end it early. A completion prompt plays when all laps finish.")
        } header: {
            Text("Yoga Sequence")
        }
    }

    private var pranayamaSection: some View {
        Section {
            HelpRow(icon: "wind", color: .cyan,
                    title: "Breath Ratio",
                    description: "Set the four phases of each breath cycle: Inhale : Hold : Exhale : Hold. For example, a 4:4:4:4 box-breath means 4 seconds for each phase. Set any phase to 0 to skip it.")
            HelpRow(icon: "speedometer", color: .cyan,
                    title: "Pace",
                    description: "Pace controls how many seconds each unit lasts. A pace of 1 means each ratio unit = 1 second. A pace of 2 doubles all timings.")
            HelpRow(icon: "bell", color: .cyan,
                    title: "Progress Sound",
                    description: "Enable the Progress Sound toggle in Settings to announce the current breath count aloud during a session.")
        } header: {
            Text("Pranayama (Breathing)")
        }
    }

    private var kriyaSection: some View {
        Section {
            HelpRow(icon: "flame", color: .red,
                    title: "Kriya Breathing",
                    description: "Kriya is a rapid rhythmic breathing technique. Set the number of breaths, the tempo (breaths per minute), and optionally add multiple stages for a full practice.")
            HelpRow(icon: "list.number", color: .red,
                    title: "Multiple Stages",
                    description: "Add as many stages as your practice requires. Each stage can have its own breath count, tempo, and breath labels. Stages play sequentially with a rest interval between them.")
            HelpRow(icon: "square.and.arrow.down", color: .red,
                    title: "Presets",
                    description: "Load a built-in preset (e.g. Kapalbhati) to get started quickly, then adjust to your own pace.")
        } header: {
            Text("Kriya")
        }
    }

    private var customSection: some View {
        Section {
            HelpRow(icon: "list.bullet.clipboard", color: .purple,
                    title: "Custom Sequences",
                    description: "Build a personalised sequence by adding poses one by one. Give each pose a name and duration. Drag to reorder or swipe to delete.")
            HelpRow(icon: "square.and.arrow.up", color: .purple,
                    title: "Export & Share",
                    description: "Export your sequence as a .yogikseq file and share it with other Yogik users via AirDrop, Messages, or email.")
            HelpRow(icon: "square.and.arrow.down", color: .purple,
                    title: "Import a Sequence",
                    description: "Tap a .yogikseq file on your device or in a message to import it directly into Yogik.")
        } header: {
            Text("Custom Sequences")
        }
    }

    private var settingsSection: some View {
        Section {
            HelpRow(icon: "person.wave.2", color: .indigo,
                    title: "Voice for Prompts",
                    description: "Choose any system voice for spoken cues. A short sample plays when you select a new voice. The list is filtered to show only natural-sounding voices.")
            HelpRow(icon: "timer", color: .indigo,
                    title: "Prep Time",
                    description: "Prep Time is a countdown before every session starts — giving you time to get into position before the first cue plays.")
            HelpRow(icon: "textformat", color: .indigo,
                    title: "Breath Labels",
                    description: "Customise the words spoken during Pranayama, e.g. change \"Inhale\" to \"Breathe in\" to match your preferred cuing style.")
        } header: {
            Text("Settings")
        }
    }

}

// MARK: – Helper Row

private struct HelpRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HelpView()
}
