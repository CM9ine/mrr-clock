import MRRClockCore
import SwiftUI

@main
struct MRRClockApp: App {
    @StateObject private var state: AppState
    private let goals: GoalStore
    private let config: Config

    init() {
        let clock = SystemClock()
        let config = StoredSettings.config
        let goals = GoalStore(storage: FileGoalStore(), clock: clock, config: config)
        self.config = config
        self.goals = goals
        let coordinator = RefreshCoordinator(
            api: { key in LiveStripeClient(key: key, transport: URLSessionTransport()) },
            keyStore: KeychainKeyStore(),
            goalStore: goals,
            cache: FileSnapshotCache(),
            clock: clock,
            config: config
        )
        _state = StateObject(wrappedValue: AppState(
            coordinator: coordinator,
            titleFormat: config.titleFormat,
            clock: clock
        ))
    }

    var body: some Scene {
        MenuBarExtra(state.title) {
            PopoverView(goalStore: goals, config: config)
                .environmentObject(state)
                .task { await state.start() }
        }
        .menuBarExtraStyle(.window)
    }
}
