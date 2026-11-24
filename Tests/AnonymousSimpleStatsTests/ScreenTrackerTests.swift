import Testing
@testable import AnonymousSimpleStats

/// Each scenario plays SwiftUI events and lists those after which `trackScreen` logs a view.
struct ScreenTrackerTests {
    enum Step: Equatable {
        case appear(active: Bool), disappear, phase(ScreenPhase), newPage(active: Bool)
    }

    /// Indexes of the steps that logged.
    func logged(_ steps: [Step]) -> [Int] {
        var tracker = ScreenTracker()
        return steps.indices.filter { i in
            switch steps[i] {
            case let .appear(active): return tracker.appeared(active: active)
            case .disappear: tracker.disappeared(); return false
            case let .phase(phase): return tracker.phaseChanged(to: phase)
            case let .newPage(active): return tracker.pageChanged(active: active)
            }
        }
    }

    @Test func logsOnceWhenShownInTheForeground() {
        #expect(logged([.appear(active: true), .phase(.active)]) == [0])
    }

    @Test func waitsForTheSceneToBeActive() {
        // At launch, the scene is still inactive when the first screen appears
        #expect(logged([.appear(active: false), .phase(.inactive), .phase(.active), .phase(.active)]) == [2])
    }

    @Test func logsAgainBackFromTheBackground() {
        #expect(logged([.appear(active: true), .phase(.inactive), .phase(.background), .phase(.inactive), .phase(.active)]) == [0, 4])
    }

    @Test func anInactiveMomentIsNotANewView() {
        // Control Center, a system alert
        #expect(logged([.appear(active: true), .phase(.inactive), .phase(.active)]) == [0])
    }

    @Test func logsAgainWhenShownAgain() {
        // Back from a pushed screen
        #expect(logged([.appear(active: true), .disappear, .appear(active: true)]) == [0, 2])
    }

    @Test func nothingOnceGone() {
        #expect(logged([.appear(active: true), .disappear, .phase(.background), .phase(.active), .newPage(active: true)]) == [0])
    }

    @Test func logsANewPageAtOnce() {
        #expect(logged([.appear(active: true), .newPage(active: true)]) == [0, 1])
    }
}
