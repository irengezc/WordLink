import AVFoundation
import UIKit

// MARK: - Audio Service (synthesized tones, no audio files required)
final class AudioService {
    static let shared = AudioService()
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    private init() {
        setupEngine()
    }

    private func setupEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        guard let engine = audioEngine, let player = playerNode else { return }
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    private func playTone(frequency: Double, duration: Double, volume: Float = 0.4) {
        guard let engine = audioEngine, let player = playerNode else { return }
        let sampleRate = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        let channelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = min(1.0, t / 0.01) * min(1.0, (duration - t) / 0.05)
            channelData[i] = Float(sin(2.0 * Double.pi * frequency * t) * Double(volume) * envelope)
        }
        if !engine.isRunning { try? engine.start() }
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    func playCorrect() {
        playTone(frequency: 523.25, duration: 0.1)  // C5
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.playTone(frequency: 659.25, duration: 0.15)  // E5
        }
    }

    func playWrong() {
        playTone(frequency: 200, duration: 0.2, volume: 0.3)
    }

    func playHint() {
        playTone(frequency: 440, duration: 0.1, volume: 0.3)  // A4
    }

    func playCompletion() {
        let notes: [(Double, Double)] = [(523.25, 0.12), (659.25, 0.12), (783.99, 0.12), (1046.5, 0.2)]
        var delay = 0.0
        for (freq, dur) in notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.playTone(frequency: freq, duration: dur)
            }
            delay += 0.13
        }
    }
}

// MARK: - Haptics Service
final class HapticsService {
    static let shared = HapticsService()
    private init() {}

    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

// MARK: - Speech Service (TTS)
final class SpeechService {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()
    private init() {}

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text.lowercased())
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.1
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
}
