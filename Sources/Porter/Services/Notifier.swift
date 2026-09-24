import Foundation
import UserNotifications

/// Local notifications only — nothing leaves the Mac.
enum Notifier {
    /// `UNUserNotificationCenter` requires a real app bundle; `swift run` doesn't have one.
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    static func requestAuthorization(completion: @escaping @MainActor (Bool) -> Void) {
        guard isAvailable else {
            Task { @MainActor in completion(false) }
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
            Task { @MainActor in completion(granted) }
        }
    }

    static func post(title: String, body: String) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: "porter.switched", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
