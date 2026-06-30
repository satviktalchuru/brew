import SwiftUI

struct RootView: View {
    var body: some View {
        Text("brew")
            .font(BrewTheme.Font.largeTitle)
            .foregroundStyle(BrewTheme.Color.textPrimary)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .brewScreenBackground()
            .tint(BrewTheme.Color.accent)
    }
}
