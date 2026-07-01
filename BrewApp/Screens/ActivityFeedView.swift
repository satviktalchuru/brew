import SwiftUI

struct ActivityFeedView: View {
    var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.activityEvents.isEmpty {
                    emptyState
                } else {
                    eventList
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .brewScreenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                }
            }
            .navigationDestination(for: DrinkLog.self) { log in
                DrinkDetailView(store: store, log: log)
            }
        }
    }

    private var eventList: some View {
        ScrollView {
            LazyVStack(spacing: BrewTheme.Spacing.xs) {
                ForEach(store.activityEvents) { event in
                    ActivityEventRow(store: store, event: event)
                        .padding(.horizontal, BrewTheme.Spacing.sm)
                }
            }
            .padding(.vertical, BrewTheme.Spacing.sm)
        }
    }

    private var emptyState: some View {
        VStack(spacing: BrewTheme.Spacing.md) {
            Image(systemName: "bell.slash")
                .font(.system(size: 44))
                .foregroundStyle(BrewTheme.Color.textTertiary)
            Text("No activity yet")
                .font(BrewTheme.Font.title3)
                .foregroundStyle(BrewTheme.Color.textPrimary)
            Text("Friend requests, coffee chats, and\nfriend activity will show up here.")
                .font(BrewTheme.Font.callout)
                .foregroundStyle(BrewTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Event Row

private struct ActivityEventRow: View {
    var store: AppStore
    var event: ActivityEvent

    var body: some View {
        BrewCard {
            VStack(alignment: .leading, spacing: BrewTheme.Spacing.sm) {
                HStack(spacing: BrewTheme.Spacing.sm) {
                    iconView

                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title)
                            .font(BrewTheme.Font.bodySemibold)
                            .foregroundStyle(BrewTheme.Color.textPrimary)
                            .lineLimit(2)
                        Text(event.subtitle)
                            .font(BrewTheme.Font.caption)
                            .foregroundStyle(BrewTheme.Color.textSecondary)
                        Text(event.date, style: .relative)
                            .font(BrewTheme.Font.caption)
                            .foregroundStyle(BrewTheme.Color.textTertiary)
                    }

                    Spacer()

                    if case .friendLog(let log, _) = event.kind {
                        NavigationLink(value: log) {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BrewTheme.Color.textTertiary)
                        }
                    }
                }

                actionButtons
            }
        }
    }

    private var iconView: some View {
        Image(systemName: event.systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(iconColor)
            .frame(width: 40, height: 40)
            .background(iconColor.opacity(0.12))
            .clipShape(Circle())
    }

    private var iconColor: Color {
        switch event.kind {
        case .friendRequest: return BrewTheme.Color.accent
        case .chatRequest: return Color(hue: 0.55, saturation: 0.6, brightness: 0.55)
        case .friendLog: return BrewTheme.Color.textSecondary
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch event.kind {
        case .friendRequest(let friendship):
            HStack(spacing: BrewTheme.Spacing.xs) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    store.acceptFriendRequest(from: friendship.requesterID)
                } label: {
                    Text("Accept")
                        .font(BrewTheme.Font.captionSemibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, BrewTheme.Spacing.sm)
                        .padding(.vertical, 8)
                        .background(BrewTheme.Color.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    store.declineFriendRequest(from: friendship.requesterID)
                } label: {
                    Text("Decline")
                        .font(BrewTheme.Font.captionSemibold)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                        .padding(.horizontal, BrewTheme.Spacing.sm)
                        .padding(.vertical, 8)
                        .background(BrewTheme.Color.border)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

        case .chatRequest(let req, let shop):
            HStack(spacing: BrewTheme.Spacing.xs) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    store.acceptChatRequest(req.id)
                } label: {
                    Text("Meet at \(shop.name.components(separatedBy: " ").first ?? shop.name)")
                        .font(BrewTheme.Font.captionSemibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, BrewTheme.Spacing.sm)
                        .padding(.vertical, 8)
                        .background(BrewTheme.Color.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    store.declineChatRequest(req.id)
                } label: {
                    Text("Decline")
                        .font(BrewTheme.Font.captionSemibold)
                        .foregroundStyle(BrewTheme.Color.textSecondary)
                        .padding(.horizontal, BrewTheme.Spacing.sm)
                        .padding(.vertical, 8)
                        .background(BrewTheme.Color.border)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

        case .friendLog:
            EmptyView()
        }
    }
}
