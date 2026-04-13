import Foundation

// MARK: - Difficulty
enum Difficulty: String, Codable, CaseIterable {
    case easy = "EASY"
    case medium = "MEDIUM"
    case hard = "HARD"

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var startingScore: Int {
        switch self {
        case .easy: return 100
        case .medium: return 80
        case .hard: return 50
        }
    }

    var hintCost: Int {
        switch self {
        case .easy: return 15
        case .medium: return 25
        case .hard: return 40
        }
    }

    var emoji: String {
        switch self {
        case .easy: return "🌱"
        case .medium: return "🔥"
        case .hard: return "💀"
        }
    }

    var description: String {
        switch self {
        case .easy: return "Common phrases & simple connections"
        case .medium: return "Idioms and everyday collocations"
        case .hard: return "Complex idioms & abstract links"
        }
    }

    var color: String {
        switch self {
        case .easy: return "emerald"
        case .medium: return "amber"
        case .hard: return "rose"
        }
    }
}

// MARK: - Phrase Info
struct PhraseInfo: Codable, Identifiable {
    var id = UUID()
    let word1: String
    let word2: String
    let explanation: String

    enum CodingKeys: String, CodingKey {
        case word1, word2, explanation
    }
}

// MARK: - History Item
struct HistoryItem: Codable, Identifiable {
    let id: String
    let date: String
    let score: Int
    let difficulty: Difficulty
    let chainLength: Int
    let phrases: [PhraseInfo]
}

// MARK: - Chain Data (from API)
struct ChainData {
    let chain: [String]
    let explanations: [String]
}

// MARK: - Game Status
enum GameStatus: Equatable {
    case start
    case difficultySelect
    case loading
    case playing
    case results
    case history
}

// MARK: - Feedback State
enum FeedbackState: Equatable {
    case none
    case correct
    case wrong
}

// MARK: - Constants
enum GameConstants {
    static let maxWords = 8
    static let poolSize = 3
}
