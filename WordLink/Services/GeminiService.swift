import Foundation

// MARK: - AI Service (via Supabase Edge Function)
final class GeminiService {

    private static let endpoint = "https://azsrjwfieyldeertdlws.supabase.co/functions/v1/generate-chain"
    private static let anonKey  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF6c3Jqd2ZpZXlsZGVlcnRkbHdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNzM5NTgsImV4cCI6MjA5MTY0OTk1OH0.biWZJ8VnVj4PYB6EoQRVJtd0OMrFmzaxtJy3DfDvW54"

    private static let fallbackData = ChainData(
        chain: ["HIGH", "SCHOOL", "BUS", "STOP", "SIGN", "LANGUAGE", "BARRIER", "REEF", "KNOT"],
        explanations: [
            "HIGH SCHOOL: A secondary school for students aged roughly 14–18.",
            "SCHOOL BUS: A vehicle that transports students to and from school.",
            "BUS STOP: A designated place where passengers board or exit a bus.",
            "STOP SIGN: A red octagonal road sign requiring vehicles to halt.",
            "SIGN LANGUAGE: A visual language using hand shapes and movements.",
            "LANGUAGE BARRIER: Difficulty communicating due to different languages.",
            "BARRIER REEF: A coral reef running parallel to a coastline.",
            "REEF KNOT: A simple, symmetrical knot used to bind two ropes together."
        ]
    )

    static func generateWordChain(difficulty: Difficulty) async -> ChainData {
        guard let url = URL(string: endpoint) else { return fallbackData }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["difficulty": difficulty.rawValue])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return fallbackData
            }

            let json = try JSONDecoder().decode(EdgeFunctionResponse.self, from: data)
            guard json.chain.count >= 9, json.explanations.count >= 8 else {
                return fallbackData
            }
            return ChainData(chain: json.chain, explanations: json.explanations)
        } catch {
            print("generate-chain error: \(error)")
            return fallbackData
        }
    }

    private struct EdgeFunctionResponse: Decodable {
        let chain: [String]
        let explanations: [String]
    }
}
