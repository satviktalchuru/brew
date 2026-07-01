import SwiftUI

struct ActivityFeedView: View {
    var store: AppStore

    var body: some View {
        NavigationStack {
            Group {
                if store.activityEvents.isEmpty {
                    VStack(spacing: BrewTheme.Spacing.md) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44))
                            .foregroundStyle(BrewTheme.Color.textTertiary)
                        Text("No recent activity")
                            .font(BrewTheme.Font.title3)
                            .foregroundStyle(BrewTheme.Color.textPrimary)
                        Text("Friend requests, chats, and friend logs will show up here.")
                            .font(BrewTheme.Font.callout)
                            .foregroundStyle(BrewTheme.Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(store.activityEvents) { event in
                        HStack(spacing: BrewTheme.Spacing.sm) {
                            Image(systemName: event.systemImage)
                                .foregroundStyle(BrewTheme.Color.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(BrewTheme.Font.bodySemibold)
                                    .foregroundStyle(BrewTheme.Color.textPrimary)
                                Text(event.subtitle)
                                    .font(BrewTheme.Font.caption)
                                    .foregroundStyle(BrewTheme.Color.textSecondary)
                            }
                            Spacer()
                            Text(event.date, style: .relative)
                                .font(BrewTheme.Font.caption)
                                .foregroundStyle(BrewTheme.Color.textTertiary)
                        }
                        .listRowBackground(BrewTheme.Color.surface)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .background(BrewTheme.Color.background)
        }
    }
}
