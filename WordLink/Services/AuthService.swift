import Foundation

/// Manages Supabase anonymous authentication.
///
/// On first launch, `ensureAuthenticated()` calls the anonymous sign-in
/// endpoint and stores the resulting tokens in UserDefaults.  On subsequent
/// launches it refreshes the access token using the persisted refresh token,
/// so the same user ID is reused indefinitely on the same device.
final class AuthService {

    static let shared = AuthService()

    // MARK: - Constants

    private static let supabaseURL = "https://azsrjwfieyldeertdlws.supabase.co"
    private static let anonKey     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF6c3Jqd2ZpZXlsZGVlcnRkbHdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNzM5NTgsImV4cCI6MjA5MTY0OTk1OH0.biWZJ8VnVj4PYB6EoQRVJtd0OMrFmzaxtJy3DfDvW54"

    private let userIdKey      = "wordlink_anon_user_id"
    private let accessTokenKey = "wordlink_anon_access_token"
    private let refreshTokenKey = "wordlink_anon_refresh_token"

    // MARK: - Public API

    /// The persisted anonymous user ID (`auth.users.id`).
    var userId: String? { UserDefaults.standard.string(forKey: userIdKey) }

    /// A valid JWT for attaching to Supabase REST / RPC requests.
    var accessToken: String? { UserDefaults.standard.string(forKey: accessTokenKey) }

    private init() {}

    /// Call once at app launch.  If tokens already exist they are refreshed;
    /// otherwise a new anonymous user is created.
    func ensureAuthenticated() async {
        if let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) {
            let refreshed = await refresh(token: refreshToken)
            if refreshed { return }
            // Refresh failed (revoked / expired beyond reuse window) — sign in fresh
        }
        await signInAnonymously()
    }

    // MARK: - Private

    private func signInAnonymously() async {
        guard let url = URL(string: "\(Self.supabaseURL)/auth/v1/signup") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [:])

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        store(json: json)
    }

    private func refresh(token: String) async -> Bool {
        guard let url = URL(string: "\(Self.supabaseURL)/auth/v1/token?grant_type=refresh_token") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": token])

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["error"] == nil)
        else { return false }

        store(json: json)
        return true
    }

    private func store(json: [String: Any]) {
        guard let accessToken  = json["access_token"]  as? String,
              let refreshToken = json["refresh_token"] as? String
        else { return }

        // user object is present on sign-in; on refresh the id is embedded in the JWT
        if let user   = json["user"] as? [String: Any],
           let userId = user["id"] as? String {
            UserDefaults.standard.set(userId, forKey: userIdKey)
        }

        UserDefaults.standard.set(accessToken,  forKey: accessTokenKey)
        UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
    }
}
