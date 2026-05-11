import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: GameViewModel

    // Background color to fill behind status bar / home indicator
    private var backgroundColor: Color {
        switch vm.gameStatus {
        case .start, .difficultySelect, .loading, .results:
            return Color(red: 0.15, green: 0.08, blue: 0.38)
        case .playing:
            return Color(.systemGroupedBackground)
        case .history:
            return Color(.systemGroupedBackground)
        }
    }

    var body: some View {
        ZStack {
            // Full-bleed background so no black bars show through on iOS 26
            backgroundColor
                .ignoresSafeArea(.all)

            // Independent `if` statements keep each view as a flat sibling in the
            // ZStack. A `switch` compiles to deeply-nested _ConditionalContent<A,
            // _ConditionalContent<B, ...>> — one wrapper per case — and on iOS 26
            // each wrapper reduces the proposed layout height, pushing content down.
            if vm.gameStatus == .start {
                HomeView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            if vm.gameStatus == .difficultySelect {
                DifficultySelectView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            if vm.gameStatus == .loading {
                LoadingView()
                    .transition(.opacity)
            }
            if vm.gameStatus == .playing {
                GameView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            if vm.gameStatus == .results {
                ResultsView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            if vm.gameStatus == .history {
                HistoryView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.gameStatus)
    }
}
