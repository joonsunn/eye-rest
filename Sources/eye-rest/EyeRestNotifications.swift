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
        statusLine(for: await authorizationState())
    }

    static func authorizationState() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func statusLine(for state: UNAuthorizationStatus) -> String {
        let detail: String
        switch state {
        case .authorized, .provisional, .ephemeral: detail = "on"
        case .denied: detail = "off — enable in Settings"
        case .notDetermined: detail = "not asked yet — answer the prompt"
        @unknown default: detail = "unknown"
        }
        return "Notifications: \(detail)"
    }

    static func openSettingsPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    static func notifyBreakStart(soundPreference: String = "system") {
        post(title: "Time for an eye break", body: "Look 20 ft away for 20 seconds.", soundPreference: soundPreference)
    }

    static func notifyBreakEnd(soundPreference: String = "system") {
        post(title: "Break over", body: "Back to work.", soundPreference: soundPreference)
    }

    static func previewBreakStart(soundPreference: String = "system") {
        post(title: "Preview — break ping", body: "This is how the break ping looks and sounds.", soundPreference: soundPreference)
    }

    static func previewBreakOver(soundPreference: String = "system") {
        post(title: "Preview — break over", body: "This is how the break-over ping looks and sounds.", soundPreference: soundPreference)
    }

    /// Names only, never paths. Files are copied from the build machine's own
    /// /System/Library/Sounds into Resources by make-app.sh, so the repo
    /// carries no Apple-owned audio. Missing files fall back to default.
    static let bundledSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    /// Resolve a ping preference to a playable sound. "system" follows the
    /// NSGlobalDomain beep pick live. Anything unresolvable falls back to default.
    static func resolveSound(preference: String, systemBeepPath: String? = nil) -> UNNotificationSound {
        var name = preference
        if name == "system" {
            let path = systemBeepPath
                ?? UserDefaults.standard.persistentDomain(forName: "NSGlobalDomain")?["com.apple.sound.beep.sound"] as? String
            name = (((path ?? "") as NSString).lastPathComponent as NSString).deletingPathExtension
        }
        if bundledSounds.contains(name) {
            return UNNotificationSound(named: UNNotificationSoundName("\(name).aiff"))
        }
        return .default
    }

    private static func post(title: String, body: String, soundPreference: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = resolveSound(preference: soundPreference)
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
