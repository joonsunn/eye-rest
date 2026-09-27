import AppKit
import SwiftUI

@main
struct EyeRestApp: App {
    @StateObject private var timer: EyeRestTimer
    @StateObject private var settings: EyeRestSettings

    init() {
        let s = EyeRestSettings()
        s.applyEnvironmentOverrides()
        let t = EyeRestTimer(workDuration: s.workDuration, breakDuration: s.breakDuration)
        t.onPhaseChange = { phase in
            switch phase {
            case .work:
                EyeRestNotifications.notifyBreakEnd()
            case .onBreak:
                EyeRestNotifications.notifyBreakStart()
            }
        }
        _timer = StateObject(wrappedValue: t)
        _settings = StateObject(wrappedValue: s)
        EyeRestNotifications.requestAuthorization()
    }

    var body: some Scene {
        MenuBarExtra {
            Text("\(phaseText): \(formattedRemaining)")
            Divider()
            Button(timer.isPaused ? "Resume" : "Pause") {
                timer.togglePause()
            }
            Button("Reset timer") {
                timer.reset()
            }
            .keyboardShortcut("r")
            Button("Skip break") {
                timer.skipBreak()
            }
            .disabled(timer.phase != .onBreak)
            Menu("Work length") {
                ForEach(EyeRestSettings.workPresets, id: \.self) { minutes in
                    Button("\(minutes) min \(Int(settings.workDuration) == minutes * 60 ? "✓" : "")") {
                        settings.setWorkMinutes(minutes)
                        timer.updateDurations(work: settings.workDuration, breakDuration: settings.breakDuration)
                    }
                }
            }
            Menu("Break length") {
                ForEach(EyeRestSettings.breakPresets, id: \.self) { seconds in
                    Button("\(seconds) sec \(Int(settings.breakDuration) == seconds ? "✓" : "")") {
                        settings.setBreakSeconds(seconds)
                        timer.updateDurations(work: settings.workDuration, breakDuration: settings.breakDuration)
                    }
                }
            }
            Divider()
            Button("Quit eye-rest") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Text(menuBarLabel)
        }
    }

    private var phaseText: String {
        switch timer.phase {
        case .work: return "Work"
        case .onBreak: return "Break"
        }
    }

    private var formattedRemaining: String {
        Self.format(timer.timeRemaining)
    }

    private var menuBarLabel: String {
        switch timer.phase {
        case .work:
            return Self.format(timer.timeRemaining)
        case .onBreak:
            return "Break \(Self.format(timer.timeRemaining))"
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
