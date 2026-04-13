import Foundation

final class StorageService {
    static let shared = StorageService()
    private let historyKey = "wordlink_history_v2"
    private let maxHistory = 20
    private init() {}

    func loadHistory() -> [HistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let items = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return []
        }
        return items
    }

    func saveHistory(item: HistoryItem) {
        var history = loadHistory()
        history.insert(item, at: 0)
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
}
