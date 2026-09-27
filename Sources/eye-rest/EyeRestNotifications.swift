import UserNotifications

enum EyeRestNotifications {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notifyBreakStart() {
        post(title: "Time for an eye break", body: "Look 20 ft away for 20 seconds.")
    }

    static func notifyBreakEnd() {
        post(title: "Break over", body: "Back to work.")
    }

    private static func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
