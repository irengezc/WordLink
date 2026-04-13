import Foundation

// MARK: - Response Models

struct StartGameResult {
    let sessionId: String
    let firstWord: String
    let totalWords: Int
    let nextWordLength: Int
    let nextHint: String
}

struct CheckGuessResult {
    let correct: Bool
    let word: String?
    let explanation: String?
    let isFinal: Bool
    let nextWordLength: Int?
    let nextHint: String?
}

struct GetHintResult {
    let hint: String
    let wordLength: Int
}

// MARK: - Service

final class SupabaseGameService {
    private static let baseURL = "https://azsrjwfieyldeertdlws.supabase.co/functions/v1"
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF6c3Jqd2ZpZXlsZGVlcnRkbHdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNzM5NTgsImV4cCI6MjA5MTY0OTk1OH0.biWZJ8VnVj4PYB6EoQRVJtd0OMrFmzaxtJy3DfDvW54"

    static func startGame(difficulty: Difficulty) async -> StartGameResult? {
        let body: [String: Any] = ["difficulty": difficulty.rawValue.lowercased()]
        guard let json = await post("start-game", body: body),
              let sessionId   = json["session_id"]     as? String,
              let firstWord   = json["first_word"]     as? String,
              let totalWords  = json["total_words"]    as? Int,
              let nextLen     = json["next_word_length"] as? Int,
              let nextHint    = json["next_hint"]      as? String
        else { return nil }
        return StartGameResult(sessionId: sessionId, firstWord: firstWord,
                               totalWords: totalWords, nextWordLength: nextLen, nextHint: nextHint)
    }

    static func checkGuess(sessionId: String, index: Int, guess: String) async -> CheckGuessResult? {
        let body: [String: Any] = ["session_id": sessionId, "index": index, "guess": guess]
        guard let json   = await post("check-guess", body: body),
              let correct = json["correct"] as? Bool
        else { return nil }
        return CheckGuessResult(
            correct:       correct,
            word:          json["word"]          as? String,
            explanation:   json["explanation"]   as? String,
            isFinal:       json["is_final"]      as? Bool ?? false,
            nextWordLength: json["next_word_length"] as? Int,
            nextHint:      json["next_hint"]     as? String
        )
    }

    static func getHint(sessionId: String, index: Int, revealedCount: Int) async -> GetHintResult? {
        let body: [String: Any] = ["session_id": sessionId, "index": index, "revealed_count": revealedCount]
        guard let json       = await post("get-hint", body: body),
              let hint       = json["hint"]        as? String,
              let wordLength = json["word_length"] as? Int
        else { return nil }
        return GetHintResult(hint: hint, wordLength: wordLength)
    }

    // MARK: - Private

    private static func post(_ endpoint: String, body: [String: Any]) async -> [String: Any]? {
        guard let url = URL(string: "\(baseURL)/\(endpoint)"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }
}
