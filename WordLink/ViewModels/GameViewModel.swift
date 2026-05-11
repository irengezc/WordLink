import Foundation
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {

    // MARK: - Game Status
    @Published var gameStatus: GameStatus = .start

    // MARK: - Session
    private var sessionId: String? = nil

    // MARK: - Chain (loaded once at game start)
    private var chain: [String] = []
    private var explanations: [String] = []

    // MARK: - Game State
    @Published var currentWord: String = ""
    @Published var targetWordDisplay: String = ""  // revealed letters + "?" placeholders
    @Published var wordLength: Int = 0
    @Published var currentIndex: Int = 0
    @Published var hintsUsed: Int = 0
    @Published var revealedLetters: Int = 1
    @Published var score: Int = 0
    @Published var isGameOver: Bool = false
    @Published var isGameWon: Bool = false
    @Published var userInput: String = ""
    @Published var feedback: FeedbackState = .none
    @Published var completedPhrases: [PhraseInfo] = []
    @Published var difficulty: Difficulty = .medium

    // MARK: - History
    @Published var history: [HistoryItem] = []
    @Published var selectedHistoryId: String? = nil

    // MARK: - Init
    init() {
        history = StorageService.shared.loadHistory()
    }

    // MARK: - Computed Properties
    var targetWord: String { targetWordDisplay }
    var revealedPrefix: String { String(targetWordDisplay.prefix(revealedLetters)) }
    var maxInputLength: Int { max(0, wordLength - revealedLetters) }
    var totalWords: Int { GameConstants.maxWords }
    private var currentTargetWord: String { chain.indices.contains(currentIndex + 1) ? chain[currentIndex + 1] : "" }

    // MARK: - Start Game
    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        gameStatus = .loading
        Task {
            if let result = await SupabaseGameService.startGame(difficulty: difficulty) {
                sessionId = result.sessionId
                setupGame(chain: result.chain, explanations: result.explanations)
            } else {
                // Fallback: AI generation
                let chainData = await GeminiService.generateWordChain(difficulty: difficulty)
                sessionId = nil
                setupGame(chain: chainData.chain, explanations: chainData.explanations)
            }
        }
    }

    private func setupGame(chain: [String], explanations: [String]) {
        self.chain = chain
        self.explanations = explanations
        currentWord = chain.first ?? ""
        let next = chain.count > 1 ? chain[1] : ""
        wordLength = next.count
        targetWordDisplay = String(next.prefix(1)) + String(repeating: "?", count: max(0, next.count - 1))
        currentIndex = 0
        hintsUsed = 0
        revealedLetters = 1
        score = difficulty.startingScore
        isGameOver = false
        isGameWon = false
        userInput = ""
        feedback = .none
        completedPhrases = []
        gameStatus = .playing
    }

    // MARK: - Input Handling
    func appendCharacter(_ char: Character) {
        guard gameStatus == .playing, !isGameOver else { return }
        let upperChar = char.uppercased().first ?? char
        guard upperChar.isLetter else { return }
        let newInput = userInput + String(upperChar)
        if newInput.count <= maxInputLength {
            userInput = newInput
            HapticsService.shared.light()
            if newInput.count == maxInputLength {
                handleGuess()
            }
        }
    }

    func deleteCharacter() {
        guard !userInput.isEmpty else { return }
        userInput.removeLast()
    }

    func handleGuess() {
        let guess = (revealedPrefix + userInput).uppercased()
        let target = currentTargetWord.uppercased()
        if guess == target {
            processCorrectGuess()
        } else {
            processWrongGuess()
        }
    }

    private func processCorrectGuess() {
        let target = currentTargetWord
        let explanation = explanations.indices.contains(currentIndex) ? explanations[currentIndex] : ""
        let points = max(10, 50 - (revealedLetters - 1) * 10)
        score += points

        let phrase = PhraseInfo(word1: currentWord, word2: target, explanation: explanation)
        completedPhrases.append(phrase)

        AudioService.shared.playCorrect()
        HapticsService.shared.success()
        SpeechService.shared.speak(target)
        feedback = .correct

        // Confirm with server in background (non-blocking)
        if let sid = sessionId {
            SupabaseGameService.confirmGuess(sessionId: sid, index: currentIndex, guess: target)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self else { return }
            self.feedback = .none
            self.userInput = ""
            self.currentWord = target
            self.currentIndex += 1
            self.revealedLetters = 1

            if self.currentIndex >= GameConstants.maxWords {
                self.finishGame(won: true)
            } else {
                let next = self.currentTargetWord
                self.wordLength = next.count
                self.targetWordDisplay = String(next.prefix(1)) + String(repeating: "?", count: max(0, next.count - 1))
            }
        }
    }

    private func processWrongGuess() {
        AudioService.shared.playWrong()
        HapticsService.shared.error()
        feedback = .wrong
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.feedback = .none
            self?.userInput = ""
        }
    }

    // MARK: - Hint (fully local)
    func useHint() {
        guard wordLength > 0, revealedLetters < wordLength else { return }
        guard score >= difficulty.hintCost else { return }
        score = max(0, score - difficulty.hintCost)
        hintsUsed += 1
        AudioService.shared.playHint()
        HapticsService.shared.medium()

        revealedLetters += 1
        let target = currentTargetWord
        targetWordDisplay = String(target.prefix(revealedLetters))
            + String(repeating: "?", count: max(0, wordLength - revealedLetters))

        let newMax = wordLength - revealedLetters
        if userInput.count > newMax {
            userInput = String(userInput.prefix(newMax))
        }

        if revealedLetters >= wordLength {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.handleGuess()
            }
        }
    }

    // MARK: - Game End
    private func finishGame(won: Bool) {
        isGameWon = won
        isGameOver = true
        if won {
            AudioService.shared.playCompletion()
            HapticsService.shared.success()
        }
        saveToHistory()
        gameStatus = .results
    }

    private func saveToHistory() {
        let item = HistoryItem(
            id: String(Date().timeIntervalSince1970),
            date: Date().formatted(date: .abbreviated, time: .shortened),
            score: score,
            difficulty: difficulty,
            chainLength: GameConstants.maxWords,
            phrases: completedPhrases
        )
        StorageService.shared.saveHistory(item: item)
        history = StorageService.shared.loadHistory()
    }

    // MARK: - Share
    func shareResult() -> String {
        var text = "🔗 WordLink - \(difficulty.displayName)\n"
        text += "Score: \(score) | \(completedPhrases.count)/\(GameConstants.maxWords) phrases\n\n"
        for phrase in completedPhrases {
            text += "\(phrase.word1) → \(phrase.word2)\n"
        }
        text += "\nPlay WordLink on iOS!"
        return text
    }

    // MARK: - Navigation
    func goHome() { gameStatus = .start }
    func goToDifficultySelect() { gameStatus = .difficultySelect }
    func goToHistory() { selectedHistoryId = nil; history = StorageService.shared.loadHistory(); gameStatus = .history }
    func clearHistory() { StorageService.shared.clearHistory(); history = [] }
}
