import Foundation

/// The user-visible states of the refresh pipeline described by docs/ARCHITECTURE.md.
public enum AppPhase: Equatable, Sendable {
    case idle
    case needsSetup
    case noGoals
    case loading(previous: Snapshot?)
    case loaded(Snapshot)
    case stale(Snapshot?, StripeError)
}

/// Coordinates stored credentials, goals, Stripe data, calculations, and snapshots using
/// the state transitions in docs/ARCHITECTURE.md and the money rules in docs/METRICS.md.
public actor RefreshCoordinator {
    private let makeAPI: @Sendable (String) -> any StripeAPI
    private let keyStore: any KeyStore
    private let goalStore: GoalStore
    private let cache: any SnapshotStorage
    private let clock: any Clock
    private let config: Config
    private var lastGoodSnapshot: Snapshot?
    private var refreshTask: Task<Void, Never>?

    public private(set) var phase: AppPhase = .idle {
        didSet { phaseContinuation?.yield(phase) }
    }
    private var phaseContinuation: AsyncStream<AppPhase>.Continuation?

    /// Creates the state machine with all external I/O and time supplied through the
    /// seams defined in docs/ARCHITECTURE.md.
    public init(
        api: @escaping @Sendable (String) -> any StripeAPI,
        keyStore: any KeyStore,
        goalStore: GoalStore,
        cache: any SnapshotStorage,
        clock: any Clock,
        config: Config
    ) {
        makeAPI = api
        self.keyStore = keyStore
        self.goalStore = goalStore
        self.cache = cache
        self.clock = clock
        self.config = config
    }

    /// Streams phase changes so the app shell can republish cached and refreshed state.
    public func phaseUpdates() -> AsyncStream<AppPhase> {
        AsyncStream { continuation in
            phaseContinuation = continuation
        }
    }

    /// Loads the last good snapshot, publishes it, and then performs one refresh.
    public func start() async {
        guard (try? keyStore.read()) != nil else {
            phase = .needsSetup
            return
        }
        guard !goalStore.goals.isEmpty else {
            phase = .noGoals
            return
        }
        lastGoodSnapshot = (try? cache.load()) ?? nil
        phase = .loading(previous: lastGoodSnapshot)
        await refresh()
    }

    /// Fetches Stripe data once and publishes a snapshot calculated under docs/METRICS.md.
    public func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        let task = Task { await self.performRefresh() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    /// Recalculates per-goal progress from cached revenue without contacting Stripe.
    public func recomputeGoals() async {
        guard !goalStore.goals.isEmpty else {
            phase = .noGoals
            return
        }
        guard let previous = currentSnapshot() ?? lastGoodSnapshot ?? ((try? cache.load()) ?? nil) else {
            await refresh()
            return
        }
        let progress = buildSnapshot(
            mrr: MRRResult(total: previous.revenue.mrr, subscriptionCount: previous.revenue.subscriptionCount, skipped: [], otherCurrencies: [], churnRisk: previous.revenue.churnRisk),
            earned: EarningsResult(total: previous.revenue.earnedToDate, transactionCount: 0, otherCurrencies: []),
            breakdown: previous.revenue.breakdown
        ).goals
        let updated = Snapshot(syncedAt: previous.syncedAt, revenue: previous.revenue, goals: progress, specVersion: metricsSpecVersion)
        try? cache.write(updated)
        lastGoodSnapshot = updated
        phase = .loaded(updated)
    }

    /// Pins a goal and recomputes its local progress without contacting Stripe.
    public func pinGoal(id: UUID) async throws {
        try goalStore.pin(id: id)
        await recomputeGoals()
    }

    private func performRefresh() async {
        guard let key = try? keyStore.read() else {
            phase = .needsSetup
            return
        }
        guard !goalStore.goals.isEmpty else {
            phase = .noGoals
            return
        }
        if lastGoodSnapshot == nil { lastGoodSnapshot = (try? cache.load()) ?? nil }
        phase = .loading(previous: lastGoodSnapshot)
        let api = makeAPI(key)
        do {
            async let subscriptions = api.activeSubscriptions(includeTrials: config.includeTrials)
            async let transactions = api.balanceTransactions(since: config.earningsStartDate)
            async let products = productNames(from: api)
            let (fetchedSubscriptions, fetchedTransactions, names) = try await (subscriptions, transactions, products)
            let mrr = MRRCalculator(clock: clock).mrr(subscriptions: fetchedSubscriptions, config: config)
            let earned = EarningsCalculator().earned(transactions: fetchedTransactions, config: config)
            let breakdown = MRRCalculator(clock: clock).breakdown(subscriptions: fetchedSubscriptions, productNames: names, config: config)
            let snapshot = buildSnapshot(mrr: mrr, earned: earned, breakdown: breakdown)
            try cache.write(snapshot)
            lastGoodSnapshot = snapshot
            phase = .loaded(snapshot)
        } catch let error as StripeError {
            phase = error == .unauthorized ? .needsSetup : .stale(lastGoodSnapshot, error)
        } catch {
            phase = .stale(lastGoodSnapshot, .network(underlying: error))
        }
    }

    private func productNames(from api: any StripeAPI) async -> [String: String] {
        guard let products = try? await api.products() else { return [:] }
        return products.reduce(into: [:]) { $0[$1.id] = $1.name }
    }

    private func buildSnapshot(mrr: MRRResult, earned: EarningsResult, breakdown: [ProductLine]) -> Snapshot {
        SnapshotBuilder(clock: clock).build(
            revenue: SnapshotRevenueInput(mrr: mrr, earned: earned, breakdown: breakdown),
            goals: goalStore.goals,
            pinnedGoalID: goalStore.pinned?.id,
            config: config
        )
    }

    private func currentSnapshot() -> Snapshot? {
        switch phase {
        case let .loaded(snapshot), let .stale(snapshot?, _), let .loading(snapshot?): snapshot
        default: nil
        }
    }
}
