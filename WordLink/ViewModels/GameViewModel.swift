import Foundation
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {

    // MARK: - Game Status
    @Published var gameStatus: GameStatus = .start

    // MARK: - Session
    private var sessionId: String? = nil

    // MARK: - Game State
    @Published var currentWord: String = ""       // the "link" word shown to user
    @Published var targetWordDisplay: String = "" // revealed letters + "?" placeholders
    @Published var wordLength: Int = 0
    private var currentTargetWord: String = ""    // full target word stored locally for instant hints
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
    @Published var isChecking: Bool = false

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

    // MARK: - Start Game
    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        gameStatus = .loading
        Task {
            if let result = await SupabaseGameService.startGame(difficulty: difficulty) {
                setupGame(from: result)
            } else {
                // Server unreachable — fall back to local AI generation
                let chainData = await GeminiService.generateWordChain(difficulty: difficulty)
                setupGameFromChain(chainData)
            }
        }
    }

    private func setupGame(from result: StartGameResult) {
        sessionId = result.sessionId
        currentWord = result.firstWord
        currentTargetWord = result.nextWord
        wordLength = result.nextWord.count
        targetWordDisplay = String(result.nextWord.prefix(1)) + String(repeating: "?", count: wordLength - 1)
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

    // Fallback: set up from a locally-generated chain (AI or reservoir)
    private func setupGameFromChain(_ chainData: ChainData) {
        sessionId = nil
        currentWord = chainData.chain.first ?? ""
        let nextWord = chainData.chain.count > 1 ? chainData.chain[1] : ""
        currentTargetWord = nextWord
        wordLength = nextWord.count
        targetWordDisplay = String(nextWord.prefix(1)) + String(repeating: "?", count: wordLength - 1)
        fallbackChain = chainData.chain
        fallbackExplanations = chainData.explanations
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

    // Fallback chain (used only when Supabase is unreachable)
    private var fallbackChain: [String] = []
    private var fallbackExplanations: [String] = []

    // MARK: - Input Handling
    func appendCharacter(_ char: Character) {
        guard gameStatus == .playing, !isGameOver, !isChecking else { return }
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
        guard !userInput.isEmpty, !isChecking else { return }
        userInput.removeLast()
    }

    func handleGuess() {
        guard !isChecking else { return }
        let guess = (revealedPrefix + userInput).uppercased()

        if let sid = sessionId {
            // Server-side validation
            isChecking = true
            Task {
                let result = await SupabaseGameService.checkGuess(sessionId: sid, index: currentIndex, guess: guess)
                isChecking = false
                if let result {
                    if result.correct {
                        processCorrectGuess(result: result)
                    } else {
                        processWrongGuess()
                    }
                } else {
                    // Network error — let user try again without penalty
                    userInput = ""
                }
            }
        } else {
            // Fallback: local validation
            let target = fallbackChain.indices.contains(currentIndex + 1) ? fallbackChain[currentIndex + 1] : ""
            if guess == target.uppercased() {
                let explanation = fallbackExplanations.indices.contains(currentIndex) ? fallbackExplanations[currentIndex] : ""
                let isFinal = currentIndex + 1 >= GameConstants.maxWords
                let nextWord = !isFinal && fallbackChain.indices.contains(currentIndex + 2) ? fallbackChain[currentIndex + 2] : ""
                let result = CheckGuessResult(
                    correct: true, word: target, explanation: explanation,
                    isFinal: isFinal,
                    nextWord: nextWord.isEmpty ? nil : nextWord
                )
                processCorrectGuess(result: result)
            } else {
                processWrongGuess()
            }
        }
    }

    private func processCorrectGuess(result: CheckGuessResult) {
        let points = max(10, 50 - (revealedLetters - 1) * 10)
        score += points

        let phrase = PhraseInfo(
            word1: currentWord,
            word2: result.word ?? "",
            explanation: result.explanation ?? ""
        )
        completedPhrases.append(phrase)

        AudioService.shared.playCorrect()
        HapticsService.shared.success()
        SpeechService.shared.speak(result.word ?? "")

        feedback = .correct

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self else { return }
            self.feedback = .none
            self.userInput = ""
            self.currentWord = result.word ?? ""
            self.currentIndex += 1

            if result.isFinal {
                self.finishGame(won: true)
            } else {
                let next = result.nextWord ?? ""
                self.currentTargetWord = next
                self.wordLength = next.count
                self.targetWordDisplay = String(next.prefix(1)) + String(repeating: "?", count: max(0, next.count - 1))
                self.revealedLetters = 1
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

    // MARK: - Hint (fully local — target word is preloaded)
    func useHint() {
        guard wordLength > 0, revealedLetters < wordLength else { return }
        guard score >= difficulty.hintCost else { return }
        score = max(0, score - difficulty.hintCost)
        hintsUsed += 1
        AudioService.shared.playHint()
        HapticsService.shared.medium()

        revealedLetters += 1
        targetWordDisplay = String(currentTargetWord.prefix(revealedLetters))
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
    func goToHistory() { selectedHistoryId = nil; gameStatus = .history }
    func clearHistory() { StorageService.shared.clearHistory(); history = [] }
}
