import SwiftUI

struct WordDisplayView: View {
    let firstWord: String
    let targetWord: String
    let revealedCount: Int
    let userInput: String
    let feedback: FeedbackState

    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            // First Word Card
            firstWordCard
            // Target Word Letter Tiles
            targetWordCard
        }
        .padding(.horizontal)
        .onChange(of: feedback) { newValue in
            if newValue == .wrong { shake() }
        }
    }

    // MARK: - First Word Card
    private var firstWordCard: some View {
        VStack(spacing: 4) {
            Text("LINK WORD")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(Color(.systemGray3))
                .tracking(2)

            Text(firstWord)
                .font(.system(size: 26, weight: .black))
                .foregroundColor(Color(.systemGray))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: Color(.systemGray5), radius: 2, y: 1)
        .scaleEffect(feedback == .correct ? 0.75 : 1.0)
        .opacity(feedback == .correct ? 0 : 1)
        .offset(y: feedback == .correct ? -40 : 0)
        .animation(.easeInOut(duration: 0.5), value: feedback)
    }

    // MARK: - Target Word Card
    private var targetWordCard: some View {
        VStack(spacing: 12) {
            letterTiles
            feedbackLabel
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(borderColor, lineWidth: 2)
        )
        .shadow(color: shadowColor, radius: 12, y: 4)
        .scaleEffect(feedback == .correct ? 1.05 : 1.0)
        .offset(x: shakeOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: feedback == .correct)
    }

    // Tiles per row before wrapping (36pt tile + 6pt gap = 42pt each; card fits ~7)
    private let maxTilesPerRow = 7

    @ViewBuilder
    private var letterTiles: some View {
        let count = targetWord.count
        if count > maxTilesPerRow {
            let half = Int(ceil(Double(count) / 2.0))
            VStack(spacing: 8) {
                tileRow(from: 0, to: half)
                tileRow(from: half, to: count)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
            tileRow(from: 0, to: count)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func tileRow(from start: Int, to end: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(start..<end, id: \.self) { index in
                let char = targetWord[targetWord.index(targetWord.startIndex, offsetBy: index)]
                LetterTile(
                    character: tileCharacter(index: index, char: char),
                    isRevealed: index < revealedCount,
                    hasUserInput: !tileCharacter(index: index, char: char).isEmpty && index >= revealedCount,
                    isCursor: isCursorPosition(index: index)
                )
            }
        }
    }

    private func tileCharacter(index: Int, char: Character) -> String {
        if index < revealedCount {
            return String(char)
        }
        let inputIndex = index - revealedCount
        if inputIndex < userInput.count {
            return String(userInput[userInput.index(userInput.startIndex, offsetBy: inputIndex)])
        }
        return ""
    }

    private func isCursorPosition(index: Int) -> Bool {
        guard index >= revealedCount else { return false }
        return index == revealedCount + userInput.count
    }

    private var feedbackLabel: some View {
        Group {
            switch feedback {
            case .wrong:
                Text("Incorrect!")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(20)
            case .correct:
                Text("Correct!")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.green)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(20)
            case .none:
                Text("\(targetWord.count) letters")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(Color(.systemGray3))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: feedback)
    }

    // MARK: - Colors
    private var cardBackground: Color {
        switch feedback {
        case .correct: return Color.green.opacity(0.05)
        case .wrong:   return Color.red.opacity(0.05)
        case .none:    return Color(.systemBackground)
        }
    }

    private var borderColor: Color {
        switch feedback {
        case .correct: return .green.opacity(0.5)
        case .wrong:   return .red.opacity(0.5)
        case .none:    return Color(.systemGray5)
        }
    }

    private var shadowColor: Color {
        switch feedback {
        case .correct: return Color.green.opacity(0.15)
        case .wrong:   return Color.red.opacity(0.15)
        case .none:    return Color(.systemGray4).opacity(0.3)
        }
    }

    // MARK: - Shake Animation
    private func shake() {
        let values: [CGFloat] = [0, -10, 10, -8, 8, -5, 5, 0]
        for (i, offset) in values.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                withAnimation(.easeInOut(duration: 0.05)) {
                    shakeOffset = offset
                }
            }
        }
    }
}

// MARK: - Letter Tile
struct LetterTile: View {
    let character: String
    let isRevealed: Bool
    let hasUserInput: Bool
    let isCursor: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(tileBackground)
            RoundedRectangle(cornerRadius: 10)
                .frame(height: 4)
                .foregroundColor(bottomColor)
                .offset(y: 18)

            if !character.isEmpty {
                Text(character)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(textColor)
            }

            if isCursor {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.indigo.opacity(0.6))
                    .frame(width: 18, height: 3)
                    .offset(y: 12)
            }
        }
        .frame(width: 36, height: 44)
        .animation(.spring(response: 0.2), value: character)
    }

    private var tileBackground: Color {
        if isRevealed { return Color.indigo.opacity(0.08) }
        if hasUserInput { return Color(.systemBackground) }
        return Color(.systemGray6)
    }

    private var bottomColor: Color {
        if isRevealed { return .indigo }
        if hasUserInput { return Color.indigo.opacity(0.4) }
        return Color(.systemGray4)
    }

    private var textColor: Color {
        if isRevealed { return .indigo }
        return Color(.label)
    }
}
