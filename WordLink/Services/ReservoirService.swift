import Foundation

// MARK: - Reservoir JSON Types
private struct ReservoirEntry: Decodable {
    let chain: [String]
    let explanations: [String]
}

private struct ReservoirFile: Decodable {
    let easy: [ReservoirEntry]
    let medium: [ReservoirEntry]
    let hard: [ReservoirEntry]
}

// MARK: - Reservoir Service
final class ReservoirService {
    static let shared = ReservoirService()

    private var reservoir: [Difficulty: [ReservoirEntry]] = [:]
    private let usedKeySuffix = "usedIndices"

    private init() {
        load()
    }

    // MARK: - Load

    private func load() {
        guard let url = Bundle.main.url(forResource: "reservoir", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(ReservoirFile.self, from: data) else {
            return
        }
        reservoir[.easy] = file.easy
        reservoir[.medium] = file.medium
        reservoir[.hard] = file.hard
    }

    // MARK: - Serve

    /// Returns a random unused ChainData for the given difficulty, or nil if exhausted.
    func next(for difficulty: Difficulty) -> ChainData? {
        guard let entries = reservoir[difficulty], !entries.isEmpty else { return nil }

        var used = usedIndices(for: difficulty)

        // Reset if all entries have been used
        if used.count >= entries.count {
            used = []
            saveUsedIndices([], for: difficulty)
        }

        let available = entries.indices.filter { !used.contains($0) }
        guard let index = available.randomElement() else { return nil }

        used.insert(index)
        saveUsedIndices(used, for: difficulty)

        let entry = entries[index]
        return ChainData(
            chain: entry.chain.map { $0.uppercased() },
            explanations: entry.explanations
        )
    }

    var easyCount: Int { reservoir[.easy]?.count ?? 0 }
    var mediumCount: Int { reservoir[.medium]?.count ?? 0 }
    var hardCount: Int { reservoir[.hard]?.count ?? 0 }

    // MARK: - UserDefaults persistence

    private func key(for difficulty: Difficulty) -> String {
        "reservoir_\(difficulty.rawValue)_\(usedKeySuffix)"
    }

    private func usedIndices(for difficulty: Difficulty) -> Set<Int> {
        let array = UserDefaults.standard.array(forKey: key(for: difficulty)) as? [Int] ?? []
        return Set(array)
    }

    private func saveUsedIndices(_ indices: Set<Int>, for difficulty: Difficulty) {
        UserDefaults.standard.set(Array(indices), forKey: key(for: difficulty))
    }
}
