import Foundation
import Testing
@testable import MRRClockCore

private final class FakeSchedulerDriver: SchedulerDriver, @unchecked Sendable {
    private let lock = NSLock()
    private var work: (@Sendable () async -> Void)?
    private(set) var requestedDelays: [TimeInterval] = []
    private(set) var cancelCount = 0

    func schedule(after delay: TimeInterval, _ work: @escaping @Sendable () async -> Void) {
        lock.withLock {
            requestedDelays.append(delay)
            self.work = work
        }
    }

    func cancel() {
        lock.withLock {
            cancelCount += 1
            work = nil
        }
    }

    func fire() async {
        let pending = lock.withLock { work }
        await pending?()
    }
}

private struct SchedulerTestFailure: Error {}

private actor SchedulerAPI: StripeAPI {
    private(set) var subscriptionsCalls = 0
    var error: StripeError?

    init(error: StripeError? = nil) {
        self.error = error
    }

    func setError(_ error: StripeError?) { self.error = error }

    func activeSubscriptions(includeTrials: Bool) async throws -> [Subscription] {
        subscriptionsCalls += 1
        if let error { throw error }
        return []
    }

    func subscriptionItems(subscriptionID: String) async throws -> [SubscriptionItem] { [] }

    func balanceTransactions(since: Date) async throws -> [BalanceTransaction] {
        if let error { throw error }
        return []
    }

    func products() async throws -> [Product] {
        if let error { throw error }
        return []
    }
}

struct RefreshSchedulerTests {
    let now = Date(iso: "2026-09-07T09:00:00Z")

    private func system(
        key: String? = "test-key",
        config: Config = .test,
        api: SchedulerAPI = SchedulerAPI(),
        cached: Snapshot? = nil
    ) -> (RefreshScheduler, FakeSchedulerDriver, SchedulerAPI) {
        let clock = FixedClock(at: now)
        let goal = Goal(
            name: "Launch",
            targetDate: Date(iso: "2027-09-07T00:00:00Z"),
            targetAmount: nil,
            createdAt: now,
            sortIndex: 0
        )
        let goals = GoalStore(
            storage: InMemoryGoalStore(file: GoalFile(goals: [goal], pinnedGoalID: goal.id)),
            clock: clock,
            config: config
        )
        let coordinator = RefreshCoordinator(
            api: { _ in api },
            keyStore: InMemoryKeyStore(key),
            goalStore: goals,
            cache: InMemorySnapshotCache(snapshot: cached),
            clock: clock,
            config: config
        )
        let driver = FakeSchedulerDriver()
        return (RefreshScheduler(coordinator: coordinator, driver: driver, clock: clock, config: config), driver, api)
    }

    @Test("refreshes once on start")
    func refreshesOnStart() async {
        let (scheduler, _, api) = system()

        await scheduler.start()

        #expect(await api.subscriptionsCalls == 1)
    }

    @Test("schedules the next refresh at the configured interval")
    func schedulesConfiguredInterval() async {
        let (scheduler, driver, _) = system()

        await scheduler.start()

        #expect(driver.requestedDelays == [900])
    }

    @Test("refreshes again when the timer fires")
    func refreshesWhenTimerFires() async {
        let (scheduler, driver, api) = system()
        await scheduler.start()
        await driver.fire()
        #expect(await api.subscriptionsCalls == 2)
    }

    @Test("enforces a five minute floor")
    func enforcesFloor() async {
        let (scheduler, driver, _) = system(config: Config(refreshInterval: 60))
        await scheduler.start()
        #expect(driver.requestedDelays == [300])
    }

    @Test("stops scheduling after stop")
    func stopsScheduling() async {
        let (scheduler, driver, api) = system()
        await scheduler.start()
        await scheduler.stop()
        await driver.fire()
        #expect(await api.subscriptionsCalls == 1)
    }

    @Test("reschedules when the interval changes")
    func reschedulesChangedInterval() async {
        let (scheduler, driver, _) = system()
        await scheduler.start()
        await scheduler.intervalChanged(to: 1800)
        #expect(driver.requestedDelays == [900, 1800])
        #expect(driver.cancelCount == 1)
    }

    @Test("backs off after a failure")
    func backsOff() async {
        let api = SchedulerAPI(error: .network(underlying: SchedulerTestFailure()))
        let (scheduler, driver, _) = system(api: api)
        await scheduler.start()
        await driver.fire()
        await driver.fire()
        #expect(driver.requestedDelays == [1800, 3600, 3600])
    }

    @Test("resets the backoff after a success")
    func resetsBackoff() async {
        let api = SchedulerAPI(error: .network(underlying: SchedulerTestFailure()))
        let (scheduler, driver, _) = system(api: api)
        await scheduler.start()
        await driver.fire()
        await api.setError(nil)
        await driver.fire()
        #expect(driver.requestedDelays == [1800, 3600, 900])
    }

    @Test("honours a longer Retry-After")
    func honoursLongRetryAfter() async {
        let api = SchedulerAPI(error: .rateLimited(retryAfter: 3600))
        let (scheduler, driver, _) = system(api: api)
        await scheduler.start()
        #expect(driver.requestedDelays == [3600])
    }

    @Test("ignores a Retry-After shorter than the interval")
    func ignoresShortRetryAfter() async {
        let api = SchedulerAPI(error: .rateLimited(retryAfter: 5))
        let (scheduler, driver, _) = system(api: api)
        await scheduler.start()
        #expect(driver.requestedDelays == [900])
    }

    @Test("refreshes on wake when the snapshot is stale")
    func refreshesOnStaleWake() async {
        let api = SchedulerAPI(error: .network(underlying: SchedulerTestFailure()))
        let (scheduler, _, _) = system(api: api, cached: snapshot(age: 1200))
        await scheduler.start()
        await scheduler.systemDidWake()
        #expect(await api.subscriptionsCalls == 2)
    }

    @Test("does not refresh on wake when the snapshot is fresh")
    func ignoresFreshWake() async {
        let api = SchedulerAPI(error: .network(underlying: SchedulerTestFailure()))
        let (scheduler, _, _) = system(api: api, cached: snapshot(age: 120))
        await scheduler.start()
        await scheduler.systemDidWake()
        #expect(await api.subscriptionsCalls == 1)
    }

    @Test("refreshes when the network returns after a failure")
    func refreshesWhenNetworkReturns() async {
        let api = SchedulerAPI(error: .network(underlying: SchedulerTestFailure()))
        let (scheduler, _, _) = system(api: api)
        await scheduler.start()
        await api.setError(nil)
        await scheduler.networkDidReturn()
        #expect(await api.subscriptionsCalls == 2)
    }

    @Test("does not refresh when the network returns while already loaded and fresh")
    func ignoresNetworkWhenFresh() async {
        let (scheduler, _, api) = system()
        await scheduler.start()
        await scheduler.networkDidReturn()
        #expect(await api.subscriptionsCalls == 1)
    }

    @Test("does not refresh at all while in needsSetup")
    func doesNotRefreshWithoutKey() async {
        let (scheduler, driver, api) = system(key: nil)
        await scheduler.start()
        await driver.fire()
        #expect(await api.subscriptionsCalls == 0)
    }

    private func snapshot(age: TimeInterval) -> Snapshot {
        Snapshot(
            syncedAt: now.addingTimeInterval(-age),
            revenue: RevenueSnapshot(
                mrr: .zero("usd"), earnedToDate: .zero("usd"), breakdown: [],
                subscriptionCount: 0, churnRisk: .zero("usd"), warnings: []
            ),
            goals: [],
            specVersion: metricsSpecVersion
        )
    }
}
