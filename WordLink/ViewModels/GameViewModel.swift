import Foundation
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {

    // MARK: - Game Status
    @Published var gameStatus: GameStatus = .start

    // MARK: - Game State
    @Published var chain: [String] = []
    @Published var explanations: [String] = []
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

    // MARK: - Pool
    private var pool: [Difficulty: [ChainData]] = [.easy: [], .medium: [], .hard: []]

    // MARK: - Init
    init() {
        history = StorageService.shared.loadHistory()
        Task { await prefillPools() }
    }

    // MARK: - Pool Management
    private func prefillPools() async {
        await withTaskGroup(of: Void.self) { group in
            // 3 medium, 1 easy, 1 hard
            for _ in 0..<3 { group.addTask { await self.refillPool(.medium) } }
            group.addTask { await self.refillPool(.easy) }
            group.addTask { await self.refillPool(.hard) }
        }
    }

    private func refillPool(_ diff: Difficulty) async {
        let data = await GeminiService.generateWordChain(difficulty: diff)
        pool[diff, default: []].append(data)
    }

    // MARK: - Start Game
    func startGame(difficulty: Difficulty) {
        self.difficulty = difficulty
        if let chainData = pool[difficulty]?.first {
            pool[difficulty]?.removeFirst()
            Task { await refillPool(difficulty) }
            setupGame(chainData: chainData)
        } else {
            gameStatus = .loading
            Task {
                let chainData = await GeminiService.generateWordChain(difficulty: difficulty)
                setupGame(chainData: chainData)
            }
        }
    }

    private func setupGame(chainData: ChainData) {
        chain = chainData.chain
        explanations = chainData.explanations
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

    // MARK: - Computed Properties
    var currentWord: String { chain.indices.contains(currentIndex) ? chain[currentIndex] : "" }
    var targetWord: String { chain.indices.contains(currentIndex + 1) ? chain[currentIndex + 1] : "" }
    var maxInputLength: Int { max(0, targetWord.count - revealedLetters) }
    var revealedPrefix: String { String(targetWord.prefix(revealedLetters)) }
    var totalWords: Int { GameConstants.maxWords }

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
        if guess == targetWord.uppercased() {
            processCorrectGuess()
        } else {
            processWrongGuess()
        }
    }

    private func processCorrectGuess() {
        let points = max(10, 50 - (revealedLetters - 1) * 10)
        score += points

        let phrase = PhraseInfo(
            word1: currentWord,
            word2: targetWord,
            explanation: explanations.indices.contains(currentIndex) ? explanations[currentIndex] : ""
        )
        completedPhrases.append(phrase)

        AudioService.shared.playCorrect()
        HapticsService.shared.success()
        SpeechService.shared.speak(targetWord)

        feedback = .correct

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self else { return }
            self.feedback = .none
            self.userInput = ""
            self.revealedLetters = 1
            self.currentIndex += 1

            if self.currentIndex >= GameConstants.maxWords {
                self.finishGame(won: true)
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

    // MARK: - Hint
    func useHint() {
        guard revealedLetters < targetWord.count else { return }
        guard score >= difficulty.hintCost else { return }
        score = max(0, score - difficulty.hintCost)
        revealedLetters += 1
        hintsUsed += 1
        AudioService.shared.playHint()
        HapticsService.shared.medium()

        // Trim user input if it now overflows
        let newMax = maxInputLength
        if userInput.count > newMax {
            userInput = String(userInput.prefix(newMax))
        }

        // Auto-submit if we've revealed all letters
        if revealedLetters >= targetWord.count {
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
    func goHome() {
        gameStatus = .start
    }

    func goToDifficultySelect() {
        gameStatus = .difficultySelect
    }

    func goToHistory() {
        selectedHistoryId = nil
        gameStatus = .history
    }

    func clearHistory() {
        StorageService.shared.clearHistory()
        history = []
    }
}
