import Foundation

// MARK: - OpenAI API Response Types
private struct OpenAIResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

private struct PairResponse: Decodable {
    let w1: String
    let w2: String
    let explanation: String
}

private struct ChainResponse: Decodable {
    let chain: [String]
    let pairs: [PairResponse]
}

// MARK: - AI Service (OpenAI backend)
final class GeminiService {
    static var apiKey: String = "REMOVED"

    private static let endpoint = "https://api.openai.com/v1/chat/completions"

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
        let complexityMap: [Difficulty: String] = [
            .easy: "very simple common two-word phrases (e.g., COLD WATER, ICE CREAM)",
            .medium: "common idioms and collocations (e.g., SOCIAL MEDIA, FIELD TRIP, HIGH SCHOOL)",
            .hard: "complex idioms and abstract connections (e.g., COLD FEET, SILVER LINING, NIGHT OWL)"
        ]

        let prompt = """
        Generate a word chain of exactly 9 English words.
        Difficulty level: \(difficulty.rawValue). Use \(complexityMap[difficulty] ?? "").

        STRICT RULES — read carefully:
        1. Every word in the chain must be a real, standalone English dictionary word.
        2. Each consecutive pair must form a common TWO-WORD PHRASE — two separate words used together as a phrase (e.g. "high school", "bus stop", "sign language", "cold water", "social media").
        3. The pair must NOT merge into a single compound word:
           - FORBIDDEN: BLACK + BIRD → "blackbird" (one merged word)
           - FORBIDDEN: WATER + FALL → "waterfall" (one merged word)
           - FORBIDDEN: CAP + TAIN → "captain" (not real words joined)
           - ALLOWED: COLD + WATER → "cold water" (genuine two-word phrase)
           - ALLOWED: HIGH + SCHOOL → "high school" (genuine two-word phrase)
        4. Ask yourself: "Is this phrase normally written as two separate words?" If yes, allowed. If one word, forbidden.

        For each of the 8 consecutive pairs, provide a "pairs" entry with the exact words and explanation.
        Respond with JSON only:
        {"chain": ["WORD1","WORD2","WORD3","WORD4","WORD5","WORD6","WORD7","WORD8","WORD9"], "pairs": [{"w1":"WORD1","w2":"WORD2","explanation":"WORD1 WORD2: one sentence definition."},{"w1":"WORD2","w2":"WORD3","explanation":"WORD2 WORD3: one sentence definition."},{"w1":"WORD3","w2":"WORD4","explanation":"WORD3 WORD4: one sentence definition."},{"w1":"WORD4","w2":"WORD5","explanation":"WORD4 WORD5: one sentence definition."},{"w1":"WORD5","w2":"WORD6","explanation":"WORD5 WORD6: one sentence definition."},{"w1":"WORD6","w2":"WORD7","explanation":"WORD6 WORD7: one sentence definition."},{"w1":"WORD7","w2":"WORD8","explanation":"WORD7 WORD8: one sentence definition."},{"w1":"WORD8","w2":"WORD9","explanation":"WORD8 WORD9: one sentence definition."}]}
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"]
        ]

        guard let url = URL(string: endpoint),
              let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return fallbackData
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return fallbackData
            }

            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let content = openAIResponse.choices.first?.message.content,
                  let jsonData = content.data(using: .utf8) else {
                return fallbackData
            }

            let chainResponse = try JSONDecoder().decode(ChainResponse.self, from: jsonData)
            let upperChain = chainResponse.chain.map { $0.uppercased().trimmingCharacters(in: .whitespaces) }

            if upperChain.count >= 9 && chainResponse.pairs.count >= 8 {
                // Match each pair by w1/w2 to guarantee correct explanation for each slot
                var orderedExplanations: [String] = []
                for i in 0..<8 {
                    let w1 = upperChain[i]
                    let w2 = upperChain[i + 1]
                    if let match = chainResponse.pairs.first(where: {
                        $0.w1.uppercased().trimmingCharacters(in: .whitespaces) == w1 &&
                        $0.w2.uppercased().trimmingCharacters(in: .whitespaces) == w2
                    }) {
                        orderedExplanations.append(match.explanation)
                    } else {
                        // Fallback: use positional index if matching fails
                        orderedExplanations.append(chainResponse.pairs.indices.contains(i) ? chainResponse.pairs[i].explanation : "")
                    }
                }
                return ChainData(chain: upperChain, explanations: orderedExplanations)
            }
            return fallbackData
        } catch {
            print("OpenAI API error: \(error)")
            return fallbackData
        }
    }
}
