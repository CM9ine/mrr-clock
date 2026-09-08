import MRRClockCore
import SwiftUI

@main
struct MRRClockApp: App {
    @StateObject private var state: AppState

    init() {
        let clock = SystemClock()
        let config = Config.default
        let goals = GoalStore(storage: FileGoalStore(), clock: clock, config: config)
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
            PopoverView()
                .environmentObject(state)
                .task { await state.start() }
        }
        .menuBarExtraStyle(.window)
    }
}
