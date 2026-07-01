import UserNotifications
import Observation

@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    var isAuthorized: Bool = false

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshAuthStatus() }
    }

    // MARK: - Permission

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run { isAuthorized = granted }
        } catch {
            // User declined or simulator environment — no-op
        }
    }

    private func refreshAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Schedule local notifications

    func scheduleFriendRequestNotification(from displayName: String) {
        guard isAuthorized else { return }
        schedule(
            id: "friend-request-\(displayName)",
            title: "New Friend Request",
            body: "\(displayName) wants to be friends on Brew.",
            sound: .default
        )
    }

    func scheduleChatRequestNotification(from displayName: String, shopName: String) {
        guard isAuthorized else { return }
        schedule(
            id: "chat-request-\(displayName)-\(shopName)",
            title: "Coffee Chat Request",
            body: "\(displayName) wants to meet at \(shopName).",
            sound: .default
        )
    }

    func scheduleFriendLoggedDrinkNotification(friend displayName: String, drinkName: String) {
        guard isAuthorized else { return }
        schedule(
            id: "friend-log-\(displayName)-\(UUID())",
            title: "\(displayName) logged a drink",
            body: "They just tried \(drinkName). Check it out!",
            sound: nil
        )
    }

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .sound, .badge])
    }

    // MARK: - Private

    private func schedule(id: String, title: String, body: String, sound: UNNotificationSound?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.badge = 1
        if let sound { content.sound = sound }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
