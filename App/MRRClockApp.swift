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
            PopoverView()
                .environmentObject(state)
                .task { await state.start() }
        }
        .menuBarExtraStyle(.window)

        Window("Goals", id: "goals") {
            NavigationStack {
                GoalListView(store: goals, config: config, revenue: state.revenue ?? emptyRevenue) {
                    Task { await state.recomputeGoals() }
                }
            }
            .environmentObject(state)
            .frame(minWidth: 520, minHeight: 500)
        }
        .defaultSize(width: 560, height: 560)

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .defaultSize(width: 460, height: 520)
    }

    private var emptyRevenue: RevenueSnapshot {
        RevenueSnapshot(mrr: .zero(config.currency), earnedToDate: .zero(config.currency), breakdown: [], subscriptionCount: 0, churnRisk: .zero(config.currency), warnings: [])
    }
}
