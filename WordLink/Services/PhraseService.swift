import Foundation

// MARK: - Model

struct Chain: Codable, Identifiable {
    let id: String
    let chain: [String]
    let explanations: [String]
    let difficulty: String
}

// MARK: - Service

/// Wraps the `get_chain` Supabase RPC function.
///
/// `getChain(difficulty:)` finds a random unseen chain for the current
/// anonymous user, records it in `user_progress`, and returns the chain.
final class ChainProgressService {

    static let shared = ChainProgressService()

    private static let supabaseURL = "https://azsrjwfieyldeertdlws.supabase.co"
    private static let anonKey     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF6c3Jqd2ZpZXlsZGVlcnRkbHdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNzM5NTgsImV4cCI6MjA5MTY0OTk1OH0.biWZJ8VnVj4PYB6EoQRVJtd0OMrFmzaxtJy3DfDvW54"

    private init() {}

    /// Returns a random chain at `difficulty` that the current user hasn't
    /// completed yet, and records it in `user_progress`.
    /// Returns `nil` when all chains at that difficulty are done or on error.
    func getChain(difficulty: String) async -> Chain? {
        guard let userId      = AuthService.shared.userId,
              let accessToken = AuthService.shared.accessToken,
              let url = URL(string: "\(Self.supabaseURL)/rest/v1/rpc/get_chain")
        else { return nil }

        let body: [String: Any] = [
            "p_user_id":    userId,
            "p_difficulty": difficulty
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",      forHTTPHeaderField: "Content-Type")
        request.setValue(Self.anonKey,            forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let rows       = try? JSONDecoder().decode([Chain].self, from: data),
              let first      = rows.first
        else { return nil }

        return first
    }
}
