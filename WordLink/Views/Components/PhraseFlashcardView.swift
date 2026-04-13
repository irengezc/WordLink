import SwiftUI

struct PhraseFlashcardView: View {
    let info: PhraseInfo
    var isLatest: Bool = false

    @State private var isFlipped = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Front
            frontSide
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? -90 : 0), axis: (x: 0, y: 1, z: 0))

            // Back
            backSide
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : 90), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isFlipped.toggle()
            }
        }
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            if isLatest {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    appeared = true
                }
            } else {
                appeared = true
            }
        }
    }

    private var frontSide: some View {
        HStack(spacing: 10) {
            Text(info.word1)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(Color(.systemGray))

            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 24, height: 24)
                Image(systemName: "link")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.indigo)
            }

            Text(info.word2)
                .font(.system(size: 19, weight: .black))
                .foregroundColor(.indigo)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .overlay(alignment: .bottomTrailing) {
            Text("Tap to flip")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(.systemGray3))
                .tracking(1)
                .padding(.bottom, 8)
                .padding(.trailing, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.indigo.opacity(0.15), lineWidth: 1.5)
        )
        .shadow(color: Color(.systemGray4).opacity(0.2), radius: 4, y: 2)
    }

    private var backSide: some View {
        VStack(spacing: 4) {
            Text("\(info.word1) + \(info.word2)")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.white.opacity(0.7))
                .tracking(1)
            Text("\"\(info.explanation)\"")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .italic()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(Color.indigo)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.indigo.opacity(0.8), lineWidth: 1.5)
        )
    }
}
