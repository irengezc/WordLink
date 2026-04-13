import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var vm: GameViewModel
    @State private var appeared = false
    @State private var showShareSheet = false
    @State private var shareText = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.45, blue: 0.28), Color(red: 0.04, green: 0.30, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.top, 20)
                        .padding(.horizontal, 24)

                    // Score Card
                    scoreCard
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .scaleEffect(appeared ? 1 : 0.8)
                        .opacity(appeared ? 1 : 0)

                    // Phrases
                    if !vm.completedPhrases.isEmpty {
                        phrasesList
                            .padding(.top, 24)
                            .padding(.horizontal, 24)
                    }

                    // Buttons
                    actionButtons
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 10) {
            Text(vm.isGameWon ? "🎉" : "😔")
                .font(.system(size: 60))

            Text(vm.isGameWon ? "Puzzle Complete!" : "Game Over")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(.white)

            Text(vm.isGameWon ? "You linked all the words!" : "Better luck next time")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Score Card
    private var scoreCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 0) {
                statItem(label: "Score", value: "\(vm.score)", icon: "star.fill", color: .yellow)
                Divider().frame(height: 50)
                statItem(label: "Phrases", value: "\(vm.completedPhrases.count)/\(GameConstants.maxWords)", icon: "link", color: .white)
                Divider().frame(height: 50)
                statItem(label: "Difficulty", value: vm.difficulty.displayName, icon: "speedometer", color: .white)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.12))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func statItem(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Phrases List
    private var phrasesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Chain")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.white.opacity(0.6))
                .tracking(1.5)

            ForEach(Array(vm.completedPhrases.enumerated()), id: \.element.id) { index, phrase in
                PhraseFlashcardView(info: phrase)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.06 + 0.3), value: appeared)
            }
        }
    }

    // MARK: - Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Play again
            Button {
                HapticsService.shared.medium()
                vm.goToDifficultySelect()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                    Text("Play Again")
                        .font(.system(size: 17, weight: .black))
                }
                .foregroundColor(.green)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
            }

            HStack(spacing: 12) {
                // Share
                Button {
                    shareText = vm.shareResult()
                    showShareSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Share")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }

                // History
                Button {
                    HapticsService.shared.light()
                    vm.goToHistory()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 14, weight: .semibold))
                        Text("History")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
            }

            // Home
            Button {
                HapticsService.shared.light()
                vm.goHome()
            } label: {
                Text("Home")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
