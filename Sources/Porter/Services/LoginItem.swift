import ServiceManagement

/// Launch at login via `SMAppService.mainApp` (macOS 13+). The system is the source of
/// truth, so nothing is stored in Porter's own preferences.
enum LoginItem {
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isEnabled: Bool {
        status == .enabled
    }

    /// The user has to approve it in System Settings › General › Login Items.
    static var needsApproval: Bool {
        status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
