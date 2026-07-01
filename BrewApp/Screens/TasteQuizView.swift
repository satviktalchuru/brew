import SwiftUI

// 3-question taste quiz shown once after onboarding sign-in.
// Answers stored in UserDefaults: brew.quizSweetness (Int), brew.quizStrength (Int), brew.quizRoast (String).
struct TasteQuizView: View {
    var store: AppStore
    var onComplete: () -> Void

    @AppStorage("brew.quizCompleted") private var quizCompleted = false
    @AppStorage("brew.quizSweetness") private var savedSweetness = 3
    @AppStorage("brew.quizStrength") private var savedStrength = 3
    @AppStorage("brew.quizRoast") private var savedRoast = "medium"

    @State private var step = 0
    @State private var sweetness = 3
    @State private var strength = 3
    @State private var roast: Roast = .medium

    private let questions = ["How sweet do you like it?", "How strong?", "Roast preference?"]

    var body: some View {
        ZStack {
            BrewTheme.Color.background.ignoresSafeArea()
            VStack(spacing: BrewTheme.Spacing.lg) {
                progressDots
                Spacer()
                questionCard
                Spacer()
                nextButton
            }
            .padding(BrewTheme.Spacing.md)
        }
    }

    private var progressDots: some View {
        HStack(spacing: BrewTheme.Spacing.xs) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(i <= step ? BrewTheme.Color.accent : BrewTheme.Color.border)
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: step)
            }
        }
        .padding(.top, BrewTheme.Spacing.md)
    }

    private var questionCard: some View {
        VStack(spacing: BrewTheme.Spacing.lg) {
            Text(questions[step])
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(BrewTheme.Color.textPrimary)
                .multilineTextAlignment(.center)
            switch step {
            case 0: sweetnessSlider
            case 1: strengthSlider
            default: roastPicker
            }
        }
        .padding(BrewTheme.Spacing.lg)
        .background(BrewTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.large, style: .continuous))
    }

    private var sweetnessSlider: some View {
        VStack(spacing: BrewTheme.Spacing.sm) {
            Text("\(sweetness)")
                .font(.system(size: 48, weight: .black, design: .serif))
                .foregroundStyle(BrewTheme.Color.accent)
            Slider(value: Binding(get: { Double(sweetness) }, set: { sweetness = Int($0.rounded()) }), in: 1...5, step: 1)
                .tint(BrewTheme.Color.accent)
            HStack {
                Text("Not sweet").font(BrewTheme.Font.caption).foregroundStyle(BrewTheme.Color.textTertiary)
                Spacer()
                Text("Very sweet").font(BrewTheme.Font.caption).foregroundStyle(BrewTheme.Color.textTertiary)
            }
        }
    }

    private var strengthSlider: some View {
        VStack(spacing: BrewTheme.Spacing.sm) {
            Text("\(strength)")
                .font(.system(size: 48, weight: .black, design: .serif))
                .foregroundStyle(BrewTheme.Color.accent)
            Slider(value: Binding(get: { Double(strength) }, set: { strength = Int($0.rounded()) }), in: 1...5, step: 1)
                .tint(BrewTheme.Color.accent)
            HStack {
                Text("Mild").font(BrewTheme.Font.caption).foregroundStyle(BrewTheme.Color.textTertiary)
                Spacer()
                Text("Intense").font(BrewTheme.Font.caption).foregroundStyle(BrewTheme.Color.textTertiary)
            }
        }
    }

    private var roastPicker: some View {
        VStack(spacing: BrewTheme.Spacing.sm) {
            ForEach([Roast.light, .medium, .dark], id: \.self) { r in
                Button {
                    roast = r
                } label: {
                    HStack {
                        Circle().fill(BrewTheme.Color.roast(r)).frame(width: 14, height: 14)
                        Text(r.label).font(BrewTheme.Font.bodySemibold).foregroundStyle(BrewTheme.Color.textPrimary)
                        Spacer()
                        if roast == r {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(BrewTheme.Color.accent)
                        }
                    }
                    .padding(BrewTheme.Spacing.sm)
                    .background(roast == r ? BrewTheme.Color.accentLight : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.small))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nextButton: some View {
        BrewPrimaryButton(step < 2 ? "Next" : "Start Brewing") {
            if step < 2 {
                withAnimation { step += 1 }
            } else {
                savedSweetness = sweetness
                savedStrength = strength
                savedRoast = roast.rawValue
                quizCompleted = true
                onComplete()
            }
        }
    }
}
