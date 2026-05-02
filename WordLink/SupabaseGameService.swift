import Foundation

// MARK: - Response Models

struct StartGameResult {
    let sessionId: String
    let chain: [String]
    let explanations: [String]
}

struct CheckGuessResult {
    let correct: Bool
    let word: String?
    let explanation: String?
    let isFinal: Bool
    let nextWord: String?
}

// MARK: - Service

final class SupabaseGameService {
    private static let baseURL = "https://azsrjwfieyldeertdlws.supabase.co/functions/v1"
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF6c3Jqd2ZpZXlsZGVlcnRkbHdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNzM5NTgsImV4cCI6MjA5MTY0OTk1OH0.biWZJ8VnVj4PYB6EoQRVJtd0OMrFmzaxtJy3DfDvW54"

    static func startGame(difficulty: Difficulty) async -> StartGameResult? {
        let body: [String: Any] = ["difficulty": difficulty.rawValue.lowercased()]
        guard let json         = await post("start-game", body: body),
              let sessionId    = json["session_id"]   as? String,
              let chain        = json["chain"]        as? [String],
              let explanations = json["explanations"] as? [String]
        else { return nil }
        return StartGameResult(sessionId: sessionId, chain: chain, explanations: explanations)
    }

    /// Fire-and-forget: confirms a correct guess server-side for session tracking.
    static func confirmGuess(sessionId: String, index: Int, guess: String) {
        Task {
            let body: [String: Any] = ["session_id": sessionId, "index": index, "guess": guess]
            _ = await post("check-guess", body: body)
        }
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
