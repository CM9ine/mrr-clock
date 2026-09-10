import MRRClockCore
import Network
import SwiftUI

@main
struct MRRClockApp: App {
    @StateObject private var state: AppState
    private let goals: GoalStore
    private let config: Config
    private let settingsKeyStore: any KeyStore
    private let scheduler: RefreshScheduler?
    @StateObject private var systemEvents = SystemEventMonitor()

    init() {
        let dependencies = AppDependencies.make()
        config = dependencies.config
        goals = dependencies.goals
        settingsKeyStore = dependencies.keyStore
        scheduler = dependencies.scheduler
        _state = StateObject(wrappedValue: dependencies.state)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(state)
                .task {
                    systemEvents.start(scheduler: scheduler)
                    await state.start()
                }
        } label: {
            Text(state.title)
                .accessibilityIdentifier("mrrclock.menu-bar-item")
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
            SettingsView(keyStore: settingsKeyStore) { interval in
                Task { await scheduler?.intervalChanged(to: interval) }
            }
        }
        .defaultSize(width: 460, height: 520)
    }

    private var emptyRevenue: RevenueSnapshot {
        RevenueSnapshot(mrr: .zero(config.currency), earnedToDate: .zero(config.currency), breakdown: [], subscriptionCount: 0, churnRisk: .zero(config.currency), warnings: [])
    }
}

@MainActor
private struct AppDependencies {
    let config: Config
    let goals: GoalStore
    let state: AppState
    let keyStore: any KeyStore
    let scheduler: RefreshScheduler?

    static func make() -> AppDependencies {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ui-testing") else { return live() }

        let clock = FixedClock(at: Date(timeIntervalSince1970: 1_800_000_000))
        let config = Config(earningsStartDate: Date(timeIntervalSince1970: 1_700_000_000))
        let testState = uiTestState(in: arguments)
        let loaded = testState == "loaded" || testState == "reordering"
        let goal = Goal(
            id: UUID(uuidString: "21000000-0000-0000-0000-000000000001")!,
            name: "Launch goal",
            targetDate: Date(timeIntervalSince1970: 1_803_456_000),
            targetAmount: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            sortIndex: 0
        )
        let seededGoals = testState == "reordering" ? reorderingGoals() : [goal]
        let file = loaded ? GoalFile(goals: seededGoals, pinnedGoalID: seededGoals.first?.id) : GoalFile()
        let goalStorage: any GoalStorage
        if testState == "reordering", let directory = uiTestGoalStoreDirectory(in: arguments) {
            let storage = FileGoalStore(directory: directory)
            let goalFile = directory.appendingPathComponent("goals.json")
            if !FileManager.default.fileExists(atPath: goalFile.path) {
                try? storage.save(file)
            }
            goalStorage = storage
        } else {
            goalStorage = InMemoryGoalStore(file: file)
        }
        let goals = GoalStore(storage: goalStorage, clock: clock, config: config)
        let state = AppState(titleFormat: config.titleFormat, clock: clock)
        if loaded {
            let snapshot = SnapshotBuilder(clock: clock).build(
                revenue: SnapshotRevenueInput(
                    mrr: MRRCalculator(clock: clock).mrr(subscriptions: [], config: config),
                    earned: EarningsCalculator().earned(transactions: [], config: config),
                    breakdown: []
                ),
                goals: goals.goals,
                pinnedGoalID: goals.pinned?.id,
                config: config
            )
            state.publish(.loaded(snapshot))
        } else {
            state.publish(.noGoals)
        }
        return AppDependencies(config: config, goals: goals, state: state, keyStore: InMemoryKeyStore(), scheduler: nil)
    }

    private static func live() -> AppDependencies {
        let clock = SystemClock()
        let config = StoredSettings.config
        let storageLocations = StorageLocations(homeDirectory: FileManager.default.homeDirectoryForCurrentUser)
        try? StorageMigrator(locations: storageLocations).migrate()
        let goals = GoalStore(storage: FileGoalStore(locations: storageLocations), clock: clock, config: config)
        let coordinator = RefreshCoordinator(
            api: { key in LiveStripeClient(key: key, transport: URLSessionTransport()) },
            keyStore: KeychainKeyStore(),
            goalStore: goals,
            cache: FileSnapshotCache(locations: storageLocations),
            clock: clock,
            config: config
        )
        let scheduler = RefreshScheduler(
            coordinator: coordinator,
            driver: FoundationTimerDriver(),
            clock: clock,
            config: config
        )
        return AppDependencies(
            config: config,
            goals: goals,
            state: AppState(coordinator: coordinator, scheduler: scheduler, titleFormat: config.titleFormat, clock: clock),
            keyStore: KeychainKeyStore(),
            scheduler: scheduler
        )
    }

    private static func uiTestState(in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "--ui-test-state"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func uiTestGoalStoreDirectory(in arguments: [String]) -> URL? {
        guard let index = arguments.firstIndex(of: "--ui-test-goal-store"), arguments.indices.contains(index + 1) else { return nil }
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    }

    private static func reorderingGoals() -> [Goal] {
        ["Alpha", "Beta", "Gamma"].enumerated().map { index, name in
            Goal(
                id: UUID(uuidString: "21000000-0000-0000-0000-00000000000\(index + 1)")!,
                name: name,
                targetDate: Date(timeIntervalSince1970: 1_803_456_000),
                targetAmount: nil,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                sortIndex: index
            )
        }
    }
}

private final class FoundationTimerDriver: SchedulerDriver, @unchecked Sendable {
    private let lock = NSLock()
    private var timer: Timer?

    func schedule(after delay: TimeInterval, _ work: @escaping @Sendable () async -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.withLock {
                self.timer?.invalidate()
                self.timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                    Task { await work() }
                }
            }
        }
    }

    func cancel() {
        DispatchQueue.main.async { [weak self] in
            self?.lock.withLock {
                self?.timer?.invalidate()
                self?.timer = nil
            }
        }
    }
}

@MainActor
private final class SystemEventMonitor: ObservableObject {
    private let network = NWPathMonitor()
    private var wakeObserver: NSObjectProtocol?
    private var started = false
    private var previousNetworkAvailable: Bool?

    func start(scheduler: RefreshScheduler?) {
        guard !started, let scheduler else { return }
        started = true
        wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in Task { await scheduler.systemDidWake() } }
        network.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor [weak self] in
                let returned = self?.previousNetworkAvailable == false && available
                self?.previousNetworkAvailable = available
                if returned { await scheduler.networkDidReturn() }
            }
        }
        network.start(queue: DispatchQueue(label: "com.mrrclock.network-monitor"))
    }

}
