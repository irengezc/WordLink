import SwiftUI

struct LoadingView: View {
    @State private var rotation: Double = 0
    @State private var dotScale: [CGFloat] = [1, 1, 1]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.25, green: 0.15, blue: 0.55), Color(red: 0.15, green: 0.08, blue: 0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Spinning link icon
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(
                            LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotation))

                    Image(systemName: "link")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .onAppear {
                    withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

                VStack(spacing: 8) {
                    Text("Loading your puzzle...")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)

                    Text("Fetching word chain")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                // Animated dots
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 8, height: 8)
                            .scaleEffect(dotScale[i])
                    }
                }
                .onAppear { animateDots() }
            }
        }
    }

    private func animateDots() {
        for i in 0..<3 {
            withAnimation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15)) {
                dotScale[i] = 1.5
            }
        }
    }
}
