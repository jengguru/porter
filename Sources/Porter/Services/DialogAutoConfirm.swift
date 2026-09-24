import AppKit
import ApplicationServices
import os

/// Optional (off by default): presses the "Use “…”" button in the macOS
/// "change your default web browser" prompt through the Accessibility API.
///
/// It is deliberately narrow, and gives up rather than guessing:
/// - it only runs for a few seconds after the user asked Porter to switch;
/// - it only looks at windows of Apple's CoreServicesUIAgent, which shows that prompt;
/// - the window must have exactly two buttons, and exactly one of them must name the
///   browser the user picked — that is the one pressed. Anything else is left alone.
@MainActor
final class DialogAutoConfirm {
    nonisolated static let agentBundleID = "com.apple.coreservices.uiagent"
    private static let watchDuration: TimeInterval = 8
    private static let pollInterval: UInt64 = 200_000_000 // 0.2s

    private let logger = Logger(subsystem: "Porter", category: "DialogAutoConfirm")
    private var task: Task<Void, Never>?

    nonisolated static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt that adds Porter to Privacy & Security › Accessibility.
    nonisolated static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    nonisolated static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func arm(targetName: String, currentName: String?) {
        disarm()
        guard Self.isTrusted else {
            logger.notice("Auto-confirm is on but Accessibility access is not granted; leaving the prompt to the user.")
            return
        }
        task = Task { @MainActor [weak self] in
            let deadline = Date().addingTimeInterval(Self.watchDuration)
            while !Task.isCancelled, Date() < deadline {
                if self?.confirmIfPresent(targetName: targetName, currentName: currentName) == true { return }
                try? await Task.sleep(nanoseconds: Self.pollInterval)
            }
            self?.logger.notice("No matching confirmation prompt found; nothing pressed.")
        }
    }

    func disarm() {
        task?.cancel()
        task = nil
    }

    private func confirmIfPresent(targetName: String, currentName: String?) -> Bool {
        for agent in NSRunningApplication.runningApplications(withBundleIdentifier: Self.agentBundleID) {
            let app = AXUIElementCreateApplication(agent.processIdentifier)
            AXUIElementSetMessagingTimeout(app, 0.5)

            for window in elements(of: app, attribute: kAXWindowsAttribute) {
                let buttons = findButtons(in: window, depth: 0)
                guard buttons.count == 2,
                      let button = Self.pick(buttons.map { ($0, title(of: $0)) }, targetName: targetName, currentName: currentName)
                else { continue }

                let result = AXUIElementPerformAction(button, kAXPressAction as CFString)
                if result == .success {
                    logger.info("Confirmed the default browser prompt.")
                    return true
                }
                logger.error("Pressing the confirmation button failed (\(result.rawValue)).")
                return false
            }
        }
        return false
    }

    /// The single button whose title names the target browser. When one browser's name
    /// contains the other's ("Google Chrome" / "Google Chrome Beta"), the button that also
    /// names the current browser is the "Keep" one and is ruled out.
    private static func pick(_ buttons: [(AXUIElement, String)], targetName: String, currentName: String?) -> AXUIElement? {
        var candidates = buttons.filter { $0.1.localizedCaseInsensitiveContains(targetName) }
        if candidates.count > 1, let currentName, currentName.localizedCaseInsensitiveCompare(targetName) != .orderedSame {
            candidates = candidates.filter { !$0.1.localizedCaseInsensitiveContains(currentName) }
        }
        return candidates.count == 1 ? candidates[0].0 : nil
    }

    // MARK: - AX helpers

    private func elements(of element: AXUIElement, attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let array = value as? [AXUIElement]
        else { return [] }
        return array
    }

    private func string(of element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func title(of element: AXUIElement) -> String {
        string(of: element, attribute: kAXTitleAttribute) ?? string(of: element, attribute: kAXDescriptionAttribute) ?? ""
    }

    private func findButtons(in element: AXUIElement, depth: Int) -> [AXUIElement] {
        guard depth < 6 else { return [] }
        var result: [AXUIElement] = []
        for child in elements(of: element, attribute: kAXChildrenAttribute) {
            if string(of: child, attribute: kAXRoleAttribute) == kAXButtonRole {
                result.append(child)
            } else {
                result += findButtons(in: child, depth: depth + 1)
            }
        }
        return result
    }
}
