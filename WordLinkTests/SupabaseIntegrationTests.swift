import XCTest
@testable import WordLink

/// Integration tests that run against the live Supabase project.
/// Requires a network connection. Each test run creates a fresh anonymous user.
final class SupabaseIntegrationTests: XCTestCase {

    // MARK: - Config

    private static let supabaseURL = "https://azsrjwfieyldeertdlws.supabase.co"
    private static let anonKey     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF6c3Jqd2ZpZXlsZGVlcnRkbHdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNzM5NTgsImV4cCI6MjA5MTY0OTk1OH0.biWZJ8VnVj4PYB6EoQRVJtd0OMrFmzaxtJy3DfDvW54"

    // MARK: - Setup

    /// Clear stored session before each test so we always start with a fresh anonymous user.
    override func setUp() async throws {
        try await super.setUp()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "wordlink_anon_user_id")
        defaults.removeObject(forKey: "wordlink_anon_access_token")
        defaults.removeObject(forKey: "wordlink_anon_refresh_token")
    }

    // MARK: - Debug helper

    func testRawAnonSignIn() async throws {
        let url = URL(string: "\(Self.supabaseURL)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [:])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "<empty>"
            print("🔍 Status: \(statusCode)")
            print("🔍 Body: \(body)")
            XCTAssertEqual(statusCode, 200, "Expected 200, got \(statusCode). Body: \(body)")
        } catch {
            print("🔴 Network error: \(error)")
            XCTFail("Network request threw: \(error)")
        }
    }

    // MARK: - Test

    func testGetChainFlow() async throws {
        // ── Step 1: Anonymous sign-in ────────────────────────────────────────
        await AuthService.shared.ensureAuthenticated()

        let userId      = try XCTUnwrap(AuthService.shared.userId,      "No user_id after ensureAuthenticated()")
        let accessToken = try XCTUnwrap(AuthService.shared.accessToken, "No access_token after ensureAuthenticated()")
        print("✅ Anonymous user created")
        print("   user_id: \(userId)")

        // ── Step 2: First get_chain call ─────────────────────────────────────
        let result1 = await ChainProgressService.shared.getChain(difficulty: "easy")
        let chain1  = try XCTUnwrap(result1, "get_chain returned nil on first call — are there 'easy' rows in the chains table?")
        print("✅ Chain 1 returned")
        print("   id:         \(chain1.id)")
        print("   chain:      \(chain1.chain)")
        print("   difficulty: \(chain1.difficulty)")

        // ── Step 3: Verify user_progress row was inserted ────────────────────
        let progressRows = try await fetchUserProgress(userId: userId, accessToken: accessToken)
        XCTAssertTrue(
            progressRows.contains(where: { $0.chainId == chain1.id }),
            "user_progress does not contain a row for chain_id \(chain1.id)"
        )
        print("✅ user_progress row confirmed for chain_id: \(chain1.id)")

        // ── Step 4: Second get_chain call — must return a different chain ─────
        let result2 = await ChainProgressService.shared.getChain(difficulty: "easy")
        let chain2  = try XCTUnwrap(result2, "get_chain returned nil on second call — need at least 2 'easy' chains in the table")
        print("✅ Chain 2 returned")
        print("   id:    \(chain2.id)")
        print("   chain: \(chain2.chain)")

        XCTAssertNotEqual(
            chain1.id, chain2.id,
            "Second call returned the same chain as the first — deduplication is not working"
        )
        print("✅ Confirmed: second chain is different from the first")
    }

    // MARK: - Helper: query user_progress via REST

    private struct ProgressRow: Decodable {
        let chainId: String
        enum CodingKeys: String, CodingKey { case chainId = "chain_id" }
    }

    private func fetchUserProgress(userId: String, accessToken: String) async throws -> [ProgressRow] {
        var components = URLComponents(string: "\(Self.supabaseURL)/rest/v1/user_progress")!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select",  value: "chain_id")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(Self.anonKey,            forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "<empty>"
            XCTFail("user_progress query failed (\(http.statusCode)): \(body)")
            return []
        }

        return try JSONDecoder().decode([ProgressRow].self, from: data)
    }
}
