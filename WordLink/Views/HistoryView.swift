import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var vm: GameViewModel
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.history.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(vm.history.enumerated()), id: \.element.id) { index, item in
                                NavigationLink(destination: GameDetailsView(item: item)) {
                                    HistoryRowView(item: item)
                                        .opacity(appeared ? 1 : 0)
                                        .offset(y: appeared ? 0 : 20)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.05), value: appeared)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticsService.shared.medium()
                        vm.goHome()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Home")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.indigo)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !vm.history.isEmpty {
                        Button {
                            HapticsService.shared.medium()
                            vm.clearHistory()
                        } label: {
                            Text("Clear")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    } else {
                        EmptyView()
                    }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    appeared = true
                }
            }
        }
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
