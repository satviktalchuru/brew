import SwiftUI

// Picks up visually where LaunchScreen.storyboard leaves off (same brown
// background, same "brew." wordmark/typeface/position) so there's no flash,
// then melts the word away character-by-character while the real app
// finishes loading underneath. Purely decorative — actual data loading
// happens in parallel in BrewApp's .task, not gated by this view.
struct LaunchMeltView: View {
    var onFinished: () -> Void

    private let characters = Array("brew.")

    // Fixed per-character variation so the melt looks organic without
    // being randomized on every render (SwiftUI re-evaluates body often).
    private let dripDelay: [Double] = [0, 0.05, 0.10, 0.03, 0.14]
    private let dripStretch: [CGFloat] = [1.8, 2.6, 1.6, 2.2, 3.0]
    private let dripDrift: [CGFloat] = [-2, 3, -4, 2, 0]

    @State private var melt: CGFloat = 0
    @State private var backgroundFade: Double = 1

    var body: some View {
        ZStack {
            Color(launchHex: "#1A0F07")
                .ignoresSafeArea()
                .opacity(backgroundFade)

            HStack(spacing: 0) {
                ForEach(Array(characters.enumerated()), id: \.offset) { index, char in
                    Text(String(char))
                        .font(.custom("Georgia-Bold", size: 48))
                        .foregroundStyle(.white)
                        .fixedSize()
                        .scaleEffect(
                            x: 1,
                            y: 1 + melt * dripStretch[index % dripStretch.count],
                            anchor: .top
                        )
                        .offset(
                            x: melt * dripDrift[index % dripDrift.count],
                            y: melt * 46
                        )
                        .blur(radius: melt * 5)
                        .opacity(1 - melt)
                }
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.0).delay(0.35)) {
                melt = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(1.3)) {
                backgroundFade = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
                onFinished()
            }
        }
    }
}

private extension Color {
    init(launchHex hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let n = UInt64(h, radix: 16) ?? 0
        self.init(red: Double((n >> 16) & 0xFF) / 255, green: Double((n >> 8) & 0xFF) / 255, blue: Double(n & 0xFF) / 255)
    }
}
