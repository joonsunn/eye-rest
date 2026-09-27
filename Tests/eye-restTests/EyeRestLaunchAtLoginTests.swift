import Foundation
import Testing
@testable import eye_rest

@MainActor
@Suite("EyeRestLaunchAtLogin")
struct EyeRestLaunchAtLoginTests {
    final class FakeService: LaunchAtLoginService {
        var enabled: Bool
        var shouldThrow = false

        init(enabled: Bool = false) {
            self.enabled = enabled
        }

        var isEnabled: Bool { enabled }

        func setEnabled(_ enabled: Bool) throws {
            if shouldThrow {
                throw NSError(domain: "eye-rest-test", code: 1)
            }
            self.enabled = enabled
        }
    }

    @Test("starts from OS status, off when never registered")
    func startsOff() {
        let manager = EyeRestLaunchAtLogin(service: FakeService(enabled: false))
        #expect(manager.isEnabled == false)
        #expect(manager.errorMessage == nil)
    }

    @Test("toggle on registers and clears errors")
    func toggleOn() {
        let manager = EyeRestLaunchAtLogin(service: FakeService())
        manager.setEnabled(true)
        #expect(manager.isEnabled == true)
        #expect(manager.errorMessage == nil)
    }

    @Test("toggle off unregisters")
    func toggleOff() {
        let manager = EyeRestLaunchAtLogin(service: FakeService(enabled: true))
        #expect(manager.isEnabled == true)
        manager.setEnabled(false)
        #expect(manager.isEnabled == false)
    }

    @Test("registration failure surfaces an error and follows OS state")
    func failureSurfacesError() {
        let service = FakeService()
        service.shouldThrow = true
        let manager = EyeRestLaunchAtLogin(service: service)
        manager.setEnabled(true)
        #expect(manager.isEnabled == false)
        #expect(manager.errorMessage != nil)
    }

    @Test("refresh adopts status flipped outside the app")
    func refreshAdoptsExternalChange() {
        let service = FakeService()
        let manager = EyeRestLaunchAtLogin(service: service)
        service.enabled = true // e.g. user flipped it in System Settings
        manager.refresh()
        #expect(manager.isEnabled == true)
    }
}
