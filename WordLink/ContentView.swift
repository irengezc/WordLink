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
        NavigationStack {
        ZStack {
            // Full-bleed background so no black bars show through on iOS 26
            backgroundColor
                .ignoresSafeArea(.all)

            switch vm.gameStatus {
            case .start:
                HomeView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

            case .difficultySelect:
                DifficultySelectView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

            case .loading:
                LoadingView()
                    .transition(.opacity)

            case .playing:
                GameView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))

            case .results:
                ResultsView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))

            case .history:
                HistoryView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.gameStatus)
        .toolbar(.hidden, for: .navigationBar)
        } // NavigationStack
    }
}
