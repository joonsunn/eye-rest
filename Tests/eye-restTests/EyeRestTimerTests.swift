import Foundation
import Testing
@testable import eye_rest

@MainActor
@Suite("EyeRestTimer transitions")
struct EyeRestTimerTests {
    @Test("work -> break -> work with shortened durations")
    func workBreakWorkCycle() {
        let timer = EyeRestTimer(workDuration: 3, breakDuration: 2, startTimerAutomatically: false)
        #expect(timer.phase == .work)
        #expect(timer.timeRemaining == 3)

        var seen: [EyeRestPhase] = []
        timer.onPhaseChange = { seen.append($0) }

        // Work countdown: 3 -> 2 -> 1 -> break.
        timer.tick()
        #expect(timer.phase == .work)
        timer.tick()
        #expect(timer.phase == .work)
        timer.tick()
        #expect(timer.phase == .onBreak)
        #expect(timer.timeRemaining == 2)
        #expect(seen == [.onBreak])

        // Break countdown: 2 -> 1 -> work.
        timer.tick()
        #expect(timer.phase == .onBreak)
        timer.tick()
        #expect(timer.phase == .work)
        #expect(timer.timeRemaining == 3)
        #expect(seen == [.onBreak, .work])
    }

    @Test("pause freezes countdown, resume continues")
    func pauseResume() {
        let timer = EyeRestTimer(workDuration: 5, breakDuration: 5, startTimerAutomatically: false)
        timer.pause()
        timer.tick()
        #expect(timer.timeRemaining == 5)
        timer.resume()
        timer.tick()
        #expect(timer.timeRemaining == 4)
    }

    @Test("skip break restarts work cycle")
    func skipBreak() {
        let timer = EyeRestTimer(workDuration: 5, breakDuration: 5, startTimerAutomatically: false)
        // No-op during work.
        timer.skipBreak()
        #expect(timer.phase == .work)

        // Advance into break, then skip.
        for _ in 0..<5 {
            timer.tick()
        }
        #expect(timer.phase == .onBreak)
        timer.skipBreak()
        #expect(timer.phase == .work)
        #expect(timer.timeRemaining == 5)
    }

    @Test("large time gap restarts work with no backlog")
    func timeGapResetsToWork() {
        var current = Date()
        let timer = EyeRestTimer(
            workDuration: 10,
            breakDuration: 5,
            startTimerAutomatically: false,
            now: { current }
        )
        // Move into break first.
        for _ in 0..<10 {
            timer.tick()
        }
        #expect(timer.phase == .onBreak)

        // Simulate sleep: jump 1 hour ahead.
        current = current.addingTimeInterval(3600)
        timer.tick()
        #expect(timer.phase == .work)
        #expect(timer.timeRemaining == 10)
    }
}
