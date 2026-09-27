import Foundation

/// Phase of the 20-20-20 cycle.
public enum EyeRestPhase: Equatable, Sendable {
    case work
    case onBreak
}

/// Wall-clock-tolerant countdown model: 20-min work, then 20-sec break, repeat.
///
/// Durations are injectable so tests can use seconds. Production defaults are
/// 20*60 work / 20 break. Call `tick()` once per second from a scheduled Timer.
///
/// Missed/slept-through breaks restart the work cycle with no backlog: if the
/// wall-clock gap since the previous tick exceeds `timeGapResetThreshold`,
/// the model silently resets to a fresh work phase instead of firing queued
/// transitions.
@MainActor
public final class EyeRestTimer: ObservableObject {
    @Published public private(set) var phase: EyeRestPhase
    @Published public private(set) var timeRemaining: TimeInterval
    @Published public private(set) var isPaused: Bool

    public let workDuration: TimeInterval
    public let breakDuration: TimeInterval
    public var onPhaseChange: ((EyeRestPhase) -> Void)?

    private var lastTick: Date
    private var timer: Timer?
    private let now: () -> Date
    private let timeGapResetThreshold: TimeInterval = 60

    public init(
        workDuration: TimeInterval = 20 * 60,
        breakDuration: TimeInterval = 20,
        startTimerAutomatically: Bool = true,
        now: @escaping () -> Date = Date.init
    ) {
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.phase = .work
        self.timeRemaining = workDuration
        self.isPaused = false
        self.now = now
        self.lastTick = now()
        if startTimerAutomatically {
            start()
        }
    }

    public func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Advance the countdown by one second. Safe to call from tests in a loop.
    public func tick() {
        let current = now()
        let gap = current.timeIntervalSince(lastTick)
        lastTick = current

        if isPaused {
            return
        }

        // Slept-through or otherwise missed time: restart fresh work, no backlog.
        if gap > timeGapResetThreshold {
            phase = .work
            timeRemaining = workDuration
            return
        }

        timeRemaining -= 1
        if timeRemaining <= 0 {
            switch phase {
            case .work:
                phase = .onBreak
                timeRemaining = breakDuration
                onPhaseChange?(.onBreak)
            case .onBreak:
                phase = .work
                timeRemaining = workDuration
                onPhaseChange?(.work)
            }
        }
    }

    public func pause() {
        isPaused = true
        lastTick = now()
    }

    public func resume() {
        isPaused = false
        lastTick = now()
    }

    public func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }

    /// Skip the current break and restart the work cycle. No-op during work.
    public func skipBreak() {
        guard phase == .onBreak else { return }
        phase = .work
        timeRemaining = workDuration
        lastTick = now()
        onPhaseChange?(.work)
    }
}
