import Foundation
import Testing
@testable import eye_rest

@MainActor
@Suite("EyeRestTimer controls")
struct EyeRestControlsTests {
    @Test("reset restarts work from any phase")
    func resetRestartsWork() {
        let timer = EyeRestTimer(workDuration: 5, breakDuration: 5, startTimerAutomatically: false)
        for _ in 0..<5 {
            timer.tick()
        }
        #expect(timer.phase == .onBreak)
        timer.reset()
        #expect(timer.phase == .work)
        #expect(timer.timeRemaining == 5)
    }

    @Test("updateDurations replaces and clamps, then resets")
    func updateDurations() {
        let timer = EyeRestTimer(workDuration: 5, breakDuration: 5, startTimerAutomatically: false)
        timer.updateDurations(work: 600, breakDuration: 30)
        #expect(timer.workDuration == 600)
        #expect(timer.breakDuration == 30)
        #expect(timer.phase == .work)
        #expect(timer.timeRemaining == 600)
        timer.updateDurations(work: 1, breakDuration: 1)
        #expect(timer.workDuration == 60)
        #expect(timer.breakDuration == 5)
    }
}

@Suite("EyeRestSettings")
struct EyeRestSettingsTests {
    private func freshDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "eye-rest-tests-\(UUID().uuidString)")!
        return defaults
    }

    @Test("defaults are 20 min work, 20 sec break")
    func defaults() {
        let settings = EyeRestSettings(defaults: freshDefaults())
        #expect(settings.workDuration == 20 * 60)
        #expect(settings.breakDuration == 20)
    }

    @Test("presets persist across instances")
    func persists() {
        let defaults = freshDefaults()
        let first = EyeRestSettings(defaults: defaults)
        first.setWorkMinutes(30)
        first.setBreakSeconds(60)
        let second = EyeRestSettings(defaults: defaults)
        #expect(second.workDuration == 30 * 60)
        #expect(second.breakDuration == 60)
    }

    @Test("environment overrides apply without persisting")
    func envOverrides() {
        let defaults = freshDefaults()
        let settings = EyeRestSettings(defaults: defaults)
        settings.applyEnvironmentOverrides([
            "EYE_REST_WORK_SECONDS": "10",
            "EYE_REST_BREAK_SECONDS": "5",
        ])
        #expect(settings.workDuration == 10)
        #expect(settings.breakDuration == 5)
        let reloaded = EyeRestSettings(defaults: defaults)
        #expect(reloaded.workDuration == 20 * 60)
    }
}
