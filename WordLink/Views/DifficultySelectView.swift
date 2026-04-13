import SwiftUI

struct DifficultySelectView: View {
    @EnvironmentObject var vm: GameViewModel
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.25, green: 0.15, blue: 0.55), Color(red: 0.15, green: 0.08, blue: 0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                Spacer()

                // Difficulty Cards
                VStack(spacing: 16) {
                    ForEach(Array(Difficulty.allCases.enumerated()), id: \.element) { index, diff in
                        DifficultyCard(difficulty: diff) {
                            HapticsService.shared.medium()
                            vm.startGame(difficulty: diff)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 30)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.08), value: appeared)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear { appeared = true }
    }

    private var headerSection: some View {
        HStack {
            Button {
                HapticsService.shared.light()
                vm.goHome()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Choose Difficulty")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.white)
                Text("Pick your challenge level")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
    }
}

// MARK: - Difficulty Card
struct DifficultyCard: View {
    let difficulty: Difficulty
    let action: () -> Void

    @State private var isPressed = false

    private var cardColors: [Color] {
        switch difficulty {
        case .easy:   return [Color(red: 0.1, green: 0.7, blue: 0.4), Color(red: 0.05, green: 0.55, blue: 0.3)]
        case .medium: return [Color(red: 0.9, green: 0.65, blue: 0.1), Color(red: 0.75, green: 0.5, blue: 0.05)]
        case .hard:   return [Color(red: 0.85, green: 0.25, blue: 0.25), Color(red: 0.7, green: 0.15, blue: 0.15)]
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Emoji bubble
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 52, height: 52)
                    Text(difficulty.emoji)
                        .font(.system(size: 26))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.displayName)
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                    Text(difficulty.description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(difficulty.startingScore) pts")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: cardColors, startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(20)
            .shadow(color: cardColors[0].opacity(0.4), radius: 12, y: 6)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.2)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.3)) { isPressed = false } }
        )
    }
}
