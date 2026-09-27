import AppKit
import os
import UserNotifications

private let log = Logger(subsystem: "com.local.eye-rest", category: "notifications")

enum EyeRestNotifications {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            log.info("auth granted=\(granted) error=\(error?.localizedDescription ?? "none")")
        }
    }

    /// One-line permission state for the menu, e.g. "authorized", "denied".
    static func statusLine() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let state: String
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: state = "on"
        case .denied: state = "off — enable in Settings"
        case .notDetermined: state = "not asked yet — relaunch"
        @unknown default: state = "unknown"
        }
        return "Notifications: \(state)"
    }

    static func openSettingsPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    static func notifyBreakStart() {
        post(title: "Time for an eye break", body: "Look 20 ft away for 20 seconds.")
    }

    static func notifyBreakEnd() {
        post(title: "Break over", body: "Back to work.")
    }

    static func notifyTest() {
        post(title: "Eye Rest test", body: "Notifications reach you. Break pings sound like this.")
    }

    private static func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            log.info("posted title=\(title) error=\(error?.localizedDescription ?? "none")")
        }
    }
}
