//
//  AudioManager.swift
//  Yogik
//
//  Created by Manbhawan on 11/01/2026.
//

import AVFoundation
import AudioToolbox

class AudioManager {
    static let shared = AudioManager()
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var isPreloaded = false
    
    init() {
        // Configure audio session to play sounds/speech even in silent mode
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        
        // Preload the speech synthesizer immediately
        // This initializes the audio engine and prevents delays on first use
        preloadSpeechSynthesizer()
    }
    
    private func preloadSpeechSynthesizer() {
        // Create a very short silent utterance to warm up the synthesizer
        let utterance = AVSpeechUtterance(string: ".")
        utterance.volume = 0.01  // Nearly silent but not zero
        utterance.rate = AVSpeechUtteranceMaximumSpeechRate  // Speak it as fast as possible
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        speechSynthesizer.speak(utterance)
        isPreloaded = true
    }
    
    // MARK: - Speech Functions
    
    func speak(message: String, voiceID: String, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = rate
        
        if let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
            utterance.voice = voice
        }
        
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
    
    // MARK: - Sound Functions
    
    func playSound(soundID: Int) {
        guard soundID != 0 else { return }
        AudioServicesPlayAlertSound(SystemSoundID(soundID))
    }
}
