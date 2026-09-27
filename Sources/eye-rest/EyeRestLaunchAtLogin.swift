import Foundation
import ServiceManagement

/// Abstraction over `SMAppService.mainApp` so tests never touch real login items.
public protocol LaunchAtLoginService {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

/// Production login item: shows in System Settings, General, Login Items.
public struct SMLoginItemService: LaunchAtLoginService {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

/// Menu-facing state for "Launch at login". Source of truth is the OS
/// registration status, read via `refresh()`; nothing cached in UserDefaults.
@MainActor
public final class EyeRestLaunchAtLogin: ObservableObject {
    @Published public private(set) var isEnabled = false
    @Published public private(set) var errorMessage: String?

    private let service: LaunchAtLoginService

    public init(service: LaunchAtLoginService = SMLoginItemService()) {
        self.service = service
        self.isEnabled = service.isEnabled
    }

    /// Re-read OS status. Call on appear: the user can flip the switch in
    /// System Settings behind our back.
    public func refresh() {
        isEnabled = service.isEnabled
    }

    public func setEnabled(_ enabled: Bool) {
        do {
            try service.setEnabled(enabled)
            isEnabled = service.isEnabled
            errorMessage = nil
        } catch {
            isEnabled = service.isEnabled
            errorMessage = error.localizedDescription
        }
    }
}
