import SwiftUI

struct FriendsView: View {
    var store: AppStore
    @State private var showAddFriends = false
    @State private var suggestions: [(user: BrewUser, mutualCount: Int)] = []

    var body: some View {
        NavigationStack {
            List {
                BrewPageTitle("Friends")
                    .listRowBackground(SwiftUI.Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))

                friendRequestsSection
                chatRequestsSection
                upcomingChatsSection
                suggestedFriendsSection
                friendsSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .brewScreenBackground()
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: BrewUser.self) { user in
                FriendProfileView(store: store, user: user)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddFriends = true } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddFriends) {
                AddFriendsSheet(store: store)
            }
            .task { await loadSuggestions() }
        }
    }

    private func loadSuggestions() async {
        if store.isSyncConfigured {
            suggestions = await store.fetchSuggestedFriendsRemote()
        } else {
            suggestions = store.suggestedFriendsLocal()
        }
    }

    // MARK: - Suggested Friends

    @ViewBuilder
    private var suggestedFriendsSection: some View {
        if !suggestions.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BrewTheme.Spacing.sm) {
                        ForEach(suggestions, id: \.user.id) { suggestion in
                            SuggestedFriendCard(store: store, user: suggestion.user, mutualCount: suggestion.mutualCount) {
                                suggestions.removeAll { $0.user.id == suggestion.user.id }
                            }
                        }
                    }
                    .padding(.vertical, BrewTheme.Spacing.xxs)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                BrewSectionLabel("Suggested for You", subtitle: "People you may know", systemImage: "person.2.badge.plus")
            }
        }
    }

    // MARK: - Inbound Friend Requests

    @ViewBuilder
    private var friendRequestsSection: some View {
        let inbound = store.pendingInboundRequests
        if !inbound.isEmpty {
            Section {
                ForEach(inbound) { request in
                    if let requester = store.user(id: request.requesterID) {
                        HStack(spacing: BrewTheme.Spacing.sm) {
                            AvatarView(user: requester, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(requester.displayName)
                                    .font(BrewTheme.Font.bodySemibold)
                                    .foregroundStyle(BrewTheme.Color.textPrimary)
                                Text("wants to be friends")
                                    .font(BrewTheme.Font.caption)
                                    .foregroundStyle(BrewTheme.Color.textSecondary)
                            }
                            Spacer()
                            Button("Accept") {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                store.acceptFriendRequest(from: requester.id)
                            }
                            .buttonStyle(AcceptButtonStyle())
                            Button("Decline") {
                                store.declineFriendRequest(from: requester.id)
                            }
                            .font(BrewTheme.Font.callout)
                            .foregroundStyle(BrewTheme.Color.textSecondary)
                        }
                        .padding(.vertical, BrewTheme.Spacing.xxs)
                        .listRowBackground(BrewTheme.Color.surface)
                    }
                }
            } header: {
                BrewSectionLabel("Friend Requests", systemImage: "person.crop.circle.badge.plus")
            }
        }
    }

    // MARK: - Chat Requests

    @ViewBuilder
    private var chatRequestsSection: some View {
        let incoming = store.chatRequests.filter {
            $0.addresseeID == store.currentUserID && $0.status == .pending
        }
        if !incoming.isEmpty {
            Section {
                ForEach(incoming) { request in
                    ChatRequestRow(store: store, request: request)
                }
            } header: {
                BrewSectionLabel("Coffee Chat Requests", systemImage: "bubble.left.and.bubble.right.fill")
            }
        }
    }

    // MARK: - Upcoming Chats

    @ViewBuilder
    private var upcomingChatsSection: some View {
        let accepted = store.chatRequests.filter {
            ($0.addresseeID == store.currentUserID || $0.requesterID == store.currentUserID)
            && $0.status == .accepted
        }
        if !accepted.isEmpty {
            Section {
                ForEach(accepted) { request in
                    UpcomingChatRow(store: store, request: request)
                }
            } header: {
                BrewSectionLabel("Upcoming Chats", systemImage: "calendar.badge.clock")
            }
        }
    }

    // MARK: - Friends List

    private var friendsSection: some View {
        Section {
            if friends.isEmpty {
                Text("No friends yet — add some!")
                    .font(BrewTheme.Font.callout)
                    .foregroundStyle(BrewTheme.Color.textTertiary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(friends) { user in
                    NavigationLink(value: user) {
                        FriendRow(store: store, user: user)
                    }
                }
            }
        } header: {
            BrewSectionLabel("Friends", systemImage: "person.2.fill")
        }
    }

    private var friends: [BrewUser] {
        let friendIDs = store.friendships
            .filter { $0.status == .accepted }
            .flatMap { [$0.requesterID, $0.addresseeID] }
            .filter { $0 != store.currentUserID }
        return friendIDs.compactMap { store.user(id: $0) }
    }
}

// MARK: - Chat Request Row

private struct ChatRequestRow: View {
    var store: AppStore
    var request: CoffeeChatRequest

    var body: some View {
        VStack(alignment: .leading, spacing: BrewTheme.Spacing.xs) {
            HStack(spacing: BrewTheme.Spacing.xs) {
                if let requester = store.user(id: request.requesterID) {
                    AvatarView(user: requester, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(requester.displayName) wants to meet you")
                            .font(BrewTheme.Font.callout)
                            .foregroundStyle(BrewTheme.Color.textPrimary)
                        if let shop = store.shop(id: request.shopID) {
                            Text("at \(shop.name)")
                                .font(BrewTheme.Font.caption)
                                .foregroundStyle(BrewTheme.Color.textSecondary)
                        }
                    }
                }
                Spacer()
            }
            HStack(spacing: BrewTheme.Spacing.xs) {
                Button("Accept") { store.acceptChatRequest(request.id) }
                    .buttonStyle(AcceptButtonStyle())

                Button("Decline") { store.declineChatRequest(request.id) }
                    .font(BrewTheme.Font.callout)
                    .foregroundStyle(BrewTheme.Color.textSecondary)
            }
        }
        .padding(.vertical, BrewTheme.Spacing.xxs)
        .listRowBackground(BrewTheme.Color.surface)
    }
}

private struct AcceptButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BrewTheme.Font.captionSemibold)
            .foregroundStyle(.white)
            .padding(.horizontal, BrewTheme.Spacing.sm)
            .padding(.vertical, 6)
            .background(BrewTheme.Color.success)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - Upcoming Chat Row

private struct UpcomingChatRow: View {
    var store: AppStore
    var request: CoffeeChatRequest

    var body: some View {
        let otherID = request.requesterID == store.currentUserID ? request.addresseeID : request.requesterID

        HStack(spacing: BrewTheme.Spacing.sm) {
            if let other = store.user(id: otherID) {
                AvatarView(user: other, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(other.displayName)
                        .font(BrewTheme.Font.bodySemibold)
                        .foregroundStyle(BrewTheme.Color.textPrimary)
                    if let shop = store.shop(id: request.shopID) {
                        Label(shop.name, systemImage: "mappin.circle.fill")
                            .font(BrewTheme.Font.caption)
                            .foregroundStyle(BrewTheme.Color.textSecondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "location.fill")
                .foregroundStyle(BrewTheme.Color.accent)
        }
        .padding(.vertical, BrewTheme.Spacing.xxs)
        .listRowBackground(BrewTheme.Color.surface)
    }
}

// MARK: - Add Friends Sheet

private struct AddFriendsSheet: View {
    var store: AppStore
    @State private var query = ""
    @State private var remoteResults: [BrewUser] = []
    @State private var isSearching = false
    @Environment(\.dismiss) private var dismiss

    private var localResults: [BrewUser] {
        let others = store.users.filter { $0.id != store.currentUserID && !store.isBlocked($0.id) }
        guard !query.isEmpty else { return others }
        return others.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.username.localizedCaseInsensitiveContains(query)
        }
    }

    private var results: [BrewUser] {
        // In sync mode, search the real profiles table; otherwise filter mock users.
        let base = store.isSyncConfigured ? remoteResults : localResults
        return base.filter { !store.isBlocked($0.id) }
    }

    var body: some View {
        NavigationStack {
            List(results) { user in
                HStack(spacing: BrewTheme.Spacing.sm) {
                    AvatarView(user: user, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName)
                            .font(BrewTheme.Font.bodySemibold)
                            .foregroundStyle(BrewTheme.Color.textPrimary)
                        Text("@\(user.username)")
                            .font(BrewTheme.Font.caption)
                            .foregroundStyle(BrewTheme.Color.textTertiary)
                    }
                    Spacer()
                    addButton(for: user)
                }
                .listRowBackground(BrewTheme.Color.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(BrewTheme.Color.background)
            .overlay { searchHint }
            .searchable(text: $query, prompt: store.isSyncConfigured ? "Search by @username or name" : "Search by name or username")
            .textInputAutocapitalization(.never)
            .task(id: query) { await runRemoteSearch() }
            .navigationTitle("Add Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var searchHint: some View {
        if store.isSyncConfigured {
            if isSearching {
                ProgressView()
            } else if query.trimmingCharacters(in: .whitespaces).count < 2 {
                ContentUnavailableView("Find friends", systemImage: "magnifyingglass",
                                       description: Text("Search by username or name to add people on Brew."))
            } else if remoteResults.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    @MainActor
    private func runRemoteSearch() async {
        guard store.isSyncConfigured else { return }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            remoteResults = []
            return
        }
        // Debounce rapid keystrokes.
        try? await Task.sleep(nanoseconds: 300_000_000)
        if Task.isCancelled { return }
        isSearching = true
        let found = await store.searchUsers(matching: trimmed)
        if Task.isCancelled { return }
        for user in found { store.upsertLocalUser(user) }
        remoteResults = found
        isSearching = false
    }

    @ViewBuilder
    private func addButton(for user: BrewUser) -> some View {
        let status = store.friendshipStatus(with: user.id)
        switch status {
        case .accepted:
            Text("Friends")
                .font(BrewTheme.Font.captionSemibold)
                .foregroundStyle(BrewTheme.Color.textTertiary)
        case .pending:
            Button("Requested") { store.cancelFriendRequest(to: user.id) }
                .font(BrewTheme.Font.captionSemibold)
                .foregroundStyle(BrewTheme.Color.textTertiary)
                .padding(.horizontal, BrewTheme.Spacing.xs)
                .padding(.vertical, 6)
                .background(BrewTheme.Color.border)
                .clipShape(Capsule())
        case nil, .blocked:
            Button("Add") { store.sendFriendRequest(to: user.id) }
                .font(BrewTheme.Font.captionSemibold)
                .foregroundStyle(.white)
                .padding(.horizontal, BrewTheme.Spacing.xs)
                .padding(.vertical, 6)
                .background(BrewTheme.Color.accent)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Suggested Friend Card

private struct SuggestedFriendCard: View {
    var store: AppStore
    var user: BrewUser
    var mutualCount: Int
    var onAdded: () -> Void

    @State private var requested = false

    var body: some View {
        VStack(spacing: BrewTheme.Spacing.xs) {
            AvatarView(user: user, size: 52)

            VStack(spacing: 1) {
                Text(user.displayName)
                    .font(BrewTheme.Font.captionSemibold)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                    .lineLimit(1)
                if mutualCount > 0 {
                    Text("\(mutualCount) mutual friend\(mutualCount == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(BrewTheme.Color.textTertiary)
                        .lineLimit(1)
                }
            }

            Button {
                store.sendFriendRequest(to: user.id)
                requested = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onAdded() }
            } label: {
                Text(requested ? "Requested" : "Add")
                    .font(BrewTheme.Font.captionSemibold)
                    .foregroundStyle(requested ? BrewTheme.Color.textTertiary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(requested ? BrewTheme.Color.border : BrewTheme.Color.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(requested)
        }
        .frame(width: 96)
        .padding(BrewTheme.Spacing.xs)
        .background(BrewTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BrewTheme.Radius.medium, style: .continuous)
                .stroke(BrewTheme.Color.border.opacity(0.7), lineWidth: 1)
        }
    }
}

// MARK: - Friend Row

private struct FriendRow: View {
    var store: AppStore
    var user: BrewUser

    var body: some View {
        HStack(spacing: BrewTheme.Spacing.sm) {
            AvatarView(user: user, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(BrewTheme.Font.bodySemibold)
                    .foregroundStyle(BrewTheme.Color.textPrimary)
                Text("@\(user.username)")
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textTertiary)
            }

            Spacer()

            let count = store.drinkLogs.filter { $0.userID == user.id }.count
            if count > 0 {
                Text("\(count) drink\(count == 1 ? "" : "s")")
                    .font(BrewTheme.Font.caption)
                    .foregroundStyle(BrewTheme.Color.textTertiary)
            }
        }
        .padding(.vertical, BrewTheme.Spacing.xxs)
        .listRowBackground(BrewTheme.Color.surface)
    }
}
