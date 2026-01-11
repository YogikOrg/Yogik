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
        AudioServicesPlaySystemSound(SystemSoundID(soundID))
    }
}
