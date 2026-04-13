import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var vm: GameViewModel
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            navBar
                .background(Color(.systemBackground))
                .shadow(color: Color(.systemGray5), radius: 1, y: 1)

            if vm.selectedHistoryId != nil {
                historyDetailView
            } else if vm.history.isEmpty {
                emptyState
            } else {
                historyListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { appeared = true }
    }

    // MARK: - Nav Bar
    private var navBar: some View {
        HStack {
            Button {
                HapticsService.shared.light()
                if vm.selectedHistoryId != nil {
                    vm.selectedHistoryId = nil
                } else {
                    vm.goHome()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text(vm.selectedHistoryId != nil ? "History" : "Home")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.indigo)
            }

            Spacer()

            Text(vm.selectedHistoryId != nil ? "Game Details" : "History")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(Color(.label))

            Spacer()

            if vm.selectedHistoryId == nil && !vm.history.isEmpty {
                Button {
                    HapticsService.shared.medium()
                    vm.clearHistory()
                } label: {
                    Text("Clear")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                }
            } else {
                Color.clear.frame(width: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - History List
    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(vm.history.enumerated()), id: \.element.id) { index, item in
                    HistoryRowView(item: item)
                        .onTapGesture {
                            HapticsService.shared.light()
                            vm.selectedHistoryId = item.id
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.05), value: appeared)
                }
            }
            .padding(20)
        }
    }

    // MARK: - History Detail
    @ViewBuilder
    private var historyDetailView: some View {
        if let id = vm.selectedHistoryId,
           let item = vm.history.first(where: { $0.id == id }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary card
                    summarySectionFor(item)

                    // Phrases
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
        }
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

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 54))
                .foregroundColor(Color(.systemGray3))
            Text("No games yet")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(Color(.systemGray))
            Text("Your completed games will appear here")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(.systemGray3))
                .multilineTextAlignment(.center)

            Button {
                HapticsService.shared.medium()
                vm.goToDifficultySelect()
            } label: {
                Text("Play Now")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.indigo)
                    .cornerRadius(14)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - History Row
struct HistoryRowView: View {
    let item: HistoryItem

    private var difficultyColor: Color {
        switch item.difficulty {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Difficulty indicator
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(difficultyColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                Text(item.difficulty.emoji)
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.difficulty.displayName)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(Color(.label))
                    Spacer()
                    Text("Score: \(item.score)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(.label))
                }

                HStack {
                    Text(item.date)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(.systemGray2))
                    Spacer()
                    Text("\(item.phrases.count)/\(item.chainLength) phrases")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(.systemGray2))
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.systemGray3))
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color(.systemGray5), radius: 3, y: 1)
    }
}
