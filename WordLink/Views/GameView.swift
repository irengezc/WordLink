import SwiftUI

struct GameView: View {
    @EnvironmentObject var vm: GameViewModel
    @FocusState private var isKeyboardFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
                .shadow(color: Color(.systemGray5), radius: 1, y: 1)

            // Progress Bar
            progressBar
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))

            // Content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        // Completed phrases
                        ForEach(Array(vm.completedPhrases.enumerated()), id: \.element.id) { index, phrase in
                            PhraseFlashcardView(
                                info: phrase,
                                isLatest: index == vm.completedPhrases.count - 1
                            )
                            .id("phrase_\(index)")
                        }

                        // Active guess area
                        if !vm.isGameOver {
                            WordDisplayView(
                                firstWord: vm.currentWord,
                                targetWord: vm.targetWord,
                                revealedCount: vm.revealedLetters,
                                userInput: vm.userInput,
                                feedback: vm.feedback
                            )
                            .id("active")
                            .padding(.top, vm.completedPhrases.isEmpty ? 0 : 8)
                        }

                        // Bottom padding for keyboard
                        Color.clear.frame(height: max(keyboardHeight + 100, 120))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .onChange(of: vm.currentIndex) { _ in
                    withAnimation {
                        proxy.scrollTo("active", anchor: .center)
                    }
                }
                .onChange(of: vm.completedPhrases.count) { count in
                    withAnimation {
                        if count > 0 {
                            proxy.scrollTo("phrase_\(count - 1)", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        // Hidden text field to capture keyboard input
        .overlay(
            TextField("", text: hiddenBinding)
                .focused($isKeyboardFocused)
                .keyboardType(.asciiCapable)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .opacity(0)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        )
        .onAppear {
            isKeyboardFocused = true
            setupKeyboardObserver()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }

    // MARK: - Hidden input binding
    private var hiddenBinding: Binding<String> {
        Binding(
            get: { vm.userInput },
            set: { newVal in
                // Only process new characters
                let old = vm.userInput
                if newVal.count > old.count {
                    let newChar = newVal[newVal.index(newVal.startIndex, offsetBy: old.count)]
                    vm.appendCharacter(newChar)
                } else if newVal.count < old.count {
                    vm.deleteCharacter()
                }
            }
        )
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button {
                HapticsService.shared.light()
                vm.goHome()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(.systemGray))
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }

            Spacer()

            VStack(spacing: 1) {
                Text("\(vm.difficulty.displayName)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(.systemGray2))
                    .tracking(1)
                Text("Score: \(vm.score)")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(Color(.label))
            }

            Spacer()

            let hintAvailable = vm.score >= vm.difficulty.hintCost
            Button {
                HapticsService.shared.light()
                vm.useHint()
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("-\(vm.difficulty.hintCost)")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(hintAvailable ? .amber : Color(.systemGray3))
                .frame(width: 44, height: 36)
                .background(hintAvailable ? Color.orange.opacity(0.12) : Color(.systemGray6))
                .cornerRadius(10)
            }
            .disabled(!hintAvailable)
        }
    }

    private var topBarHeight: CGFloat { 60 }

    // MARK: - Progress Bar
    private var progressBar: some View {
        HStack(spacing: 5) {
            ForEach(0..<GameConstants.maxWords, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(i < vm.currentIndex ? Color.indigo : (i == vm.currentIndex ? Color.indigo.opacity(0.3) : Color(.systemGray5)))
                    .frame(height: 6)
                    .animation(.spring(response: 0.3), value: vm.currentIndex)
            }
        }
    }

    // MARK: - Keyboard observer
    private func setupKeyboardObserver() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation { keyboardHeight = frame.height }
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation { keyboardHeight = 0 }
        }
    }
}

// MARK: - Color extension for amber
extension Color {
    static let amber = Color(red: 0.9, green: 0.65, blue: 0.1)
}
