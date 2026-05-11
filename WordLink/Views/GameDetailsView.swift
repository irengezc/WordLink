import SwiftUI

struct GameDetailsView: View {
    let item: HistoryItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summarySectionFor(item)

                if !item.phrases.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Word Chain")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(Color(.systemGray2))
                            .tracking(1.5)

                        ForEach(item.phrases) { phrase in
                            PhraseFlashcardView(info: phrase)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Game Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func summarySectionFor(_ item: HistoryItem) -> some View {
        HStack(spacing: 0) {
            statCell(label: "Score", value: "\(item.score)")
            Divider().frame(height: 40)
            statCell(label: "Phrases", value: "\(item.phrases.count)/\(item.chainLength)")
            Divider().frame(height: 40)
            statCell(label: "Mode", value: item.difficulty.displayName)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color(.systemGray5), radius: 4, y: 2)
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundColor(Color(.label))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(.systemGray2))
        }
        .frame(maxWidth: .infinity)
    }
}

