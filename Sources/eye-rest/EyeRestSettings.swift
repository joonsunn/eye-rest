import Foundation

/// Work/break durations in seconds, persisted locally. No network, no sync.
public final class EyeRestSettings: ObservableObject {
    public static let workPresets = [5, 15, 20, 30, 45]
    public static let breakPresets = [20, 30, 60]

    @Published public private(set) var workDuration: TimeInterval
    @Published public private(set) var breakDuration: TimeInterval

    private let defaults: UserDefaults
    private static let workKey = "eye-rest.workDuration"
    private static let breakKey = "eye-rest.breakDuration"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let work = defaults.double(forKey: Self.workKey)
        let rest = defaults.double(forKey: Self.breakKey)
        self.workDuration = work > 0 ? work : 20 * 60
        self.breakDuration = rest > 0 ? rest : 20
    }

    public func setWorkMinutes(_ minutes: Int) {
        set(work: TimeInterval(minutes * 60), breakDuration: breakDuration)
    }

    public func setBreakSeconds(_ seconds: Int) {
        set(work: workDuration, breakDuration: TimeInterval(seconds))
    }

    /// Seconds-level override for testing: EYE_REST_WORK_SECONDS / EYE_REST_BREAK_SECONDS.
    public func applyEnvironmentOverrides(_ env: [String: String] = ProcessInfo.processInfo.environment) {
        var work = workDuration
        var rest = breakDuration
        if let raw = env["EYE_REST_WORK_SECONDS"], let value = TimeInterval(raw), value >= 1 {
            work = value
        }
        if let raw = env["EYE_REST_BREAK_SECONDS"], let value = TimeInterval(raw), value >= 1 {
            rest = value
        }
        set(work: work, breakDuration: rest, persist: false)
    }

    private func set(work: TimeInterval, breakDuration: TimeInterval, persist: Bool = true) {
        workDuration = work
        self.breakDuration = breakDuration
        if persist {
            defaults.set(work, forKey: Self.workKey)
            defaults.set(breakDuration, forKey: Self.breakKey)
        }
    }
}
