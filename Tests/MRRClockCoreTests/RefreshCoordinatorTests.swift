import Foundation
import Testing
@testable import MRRClockCore

private struct TestFailure: Error {}

private actor Gate {
    var open = false
    var waiters: [CheckedContinuation<Void, Never>] = []
    var observers: [(Int, CheckedContinuation<Void, Never>)] = []
    func wait() async { if !open { await withCheckedContinuation { waiters.append($0); notify() } } }
    func waitFor(_ count: Int) async { if waiters.count < count { await withCheckedContinuation { observers.append((count, $0)) } } }
    func release() { open = true; let pending = waiters; waiters = []; pending.forEach { $0.resume() }; notify() }
    private func notify() { let ready = observers.filter { waiters.count >= $0.0 }; observers.removeAll { waiters.count >= $0.0 }; ready.forEach { $0.1.resume() } }
}

private actor ScriptedAPI: StripeAPI {
    private(set) var subscriptionsCalls = 0
    private(set) var transactionsCalls = 0
    private(set) var productsCalls = 0
    var subscriptions: [Subscription]
    var transactions: [BalanceTransaction]
    var seededProducts: [Product]
    var error: StripeError?
    var productsError: StripeError?
    let gate: Gate?
    init(subscriptions: [Subscription] = [], transactions: [BalanceTransaction] = [], products: [Product] = [], error: StripeError? = nil, productsError: StripeError? = nil, gate: Gate? = nil) {
        self.subscriptions = subscriptions; self.transactions = transactions; seededProducts = products; self.error = error; self.productsError = productsError; self.gate = gate
    }
    func setSubscriptions(_ value: [Subscription]) { subscriptions = value }
    func setError(_ value: StripeError?) { error = value }
    func activeSubscriptions(includeTrials: Bool) async throws -> [Subscription] { subscriptionsCalls += 1; if let gate { await gate.wait() }; if let error { throw error }; return subscriptions }
    func subscriptionItems(subscriptionID: String) async throws -> [SubscriptionItem] { [] }
    func balanceTransactions(since: Date) async throws -> [BalanceTransaction] { transactionsCalls += 1; if let gate { await gate.wait() }; if let error { throw error }; return transactions }
    func products() async throws -> [Product] { productsCalls += 1; if let gate { await gate.wait() }; if let productsError { throw productsError }; if let error { throw error }; return seededProducts }
}

struct RefreshCoordinatorTests {
    let now = Date(iso: "2026-09-07T09:00:00Z")
    let key = "test-key"
    func goal(_ name: String = "Launch", _ index: Int = 0) -> Goal { Goal(name: name, targetDate: Date(iso: "2027-09-07T00:00:00Z"), targetAmount: Money(100_000, "usd"), createdAt: now, sortIndex: index) }
    func oldSnapshot(_ mrr: Int = 500) -> Snapshot { Snapshot(syncedAt: Date(iso: "2026-09-01T09:00:00Z"), revenue: RevenueSnapshot(mrr: Money(mrr, "usd"), earnedToDate: Money(2_000, "usd"), breakdown: [], subscriptionCount: 1, churnRisk: .zero("usd"), warnings: []), goals: [], specVersion: metricsSpecVersion) }
    func subscription(_ amount: Int, product: String = "prod_1") -> Subscription { .stub(items: [.stub(price: .stub(product: product, unitAmount: amount))]) }
    func system(key storedKey: String? = "test-key", goals: [Goal]? = nil, api: any StripeAPI, cached: Snapshot? = nil) -> (RefreshCoordinator, InMemoryKeyStore, GoalStore, InMemorySnapshotCache) {
        let actualGoals = goals ?? [goal()]
        let keys = InMemoryKeyStore(storedKey)
        let store = GoalStore(storage: InMemoryGoalStore(file: GoalFile(goals: actualGoals, pinnedGoalID: actualGoals.first?.id)), clock: FixedClock(at: now), config: .test)
        let cache = InMemorySnapshotCache(snapshot: cached)
        return (RefreshCoordinator(api: { _ in api }, keyStore: keys, goalStore: store, cache: cache, clock: FixedClock(at: now), config: .test), keys, store, cache)
    }

    @Test("starts in needsSetup when there is no key") func noKey() async { let api = ScriptedAPI(); let (c,_,_,_) = system(key: nil, api: api); await c.start(); #expect(await c.phase == .needsSetup); #expect(await api.subscriptionsCalls == 0); #expect(await api.transactionsCalls == 0); #expect(await api.productsCalls == 0) }
    @Test("starts in noGoals when there is a key but no goals") func noGoals() async { let api = ScriptedAPI(); let (c,_,_,_) = system(goals: [], api: api); await c.start(); #expect(await c.phase == .noGoals); #expect(await api.subscriptionsCalls == 0); #expect(await api.transactionsCalls == 0); #expect(await api.productsCalls == 0) }
    @Test("publishes the cached snapshot before the network returns") func loadingCache() async { let gate = Gate(); let old = oldSnapshot(); let api = ScriptedAPI(gate: gate); let (c,_,_,_) = system(api: api, cached: old); let task = Task { await c.start() }; await gate.waitFor(3); #expect(await c.phase == .loading(previous: old)); await gate.release(); await task.value }
    @Test("ends in loaded after a successful start") func startLoads() async { let api = ScriptedAPI(subscriptions: [subscription(1_000)]); let (c,_,_,_) = system(api: api); await c.start(); guard case .loaded = await c.phase else { Issue.record("Expected loaded"); return } }
    @Test("fetches subscriptions, transactions and products once each") func callsEach() async { let api = ScriptedAPI(); let (c,_,_,_) = system(api: api); await c.refresh(); #expect(await api.subscriptionsCalls == 1); #expect(await api.transactionsCalls == 1); #expect(await api.productsCalls == 1) }
    @Test("produces a snapshot with one entry per goal") func goalEntries() async { let api = ScriptedAPI(); let (c,_,_,_) = system(goals: [goal("One"), goal("Two", 1)], api: api); await c.refresh(); guard case let .loaded(s) = await c.phase else { Issue.record("Expected loaded"); return }; #expect(s.goals.count == 2) }
    @Test("writes the snapshot to the cache") func cacheWrite() async { let api = ScriptedAPI(); let (c,_,_,cache) = system(api: api); await c.refresh(); guard case let .loaded(s) = await c.phase else { Issue.record("Expected loaded"); return }; #expect(cache.writeCount == 1); #expect(cache.snapshot == s) }
    @Test("stamps syncedAt from the clock") func syncedAt() async { let api = ScriptedAPI(); let (c,_,_,_) = system(api: api); await c.refresh(); guard case let .loaded(s) = await c.phase else { Issue.record("Expected loaded"); return }; #expect(s.syncedAt == now) }
    @Test("a second refresh replaces the snapshot") func replacement() async { let api = ScriptedAPI(subscriptions: [subscription(1_000)]); let (c,_,_,_) = system(api: api); await c.refresh(); await api.setSubscriptions([subscription(2_000)]); await c.refresh(); guard case let .loaded(s) = await c.phase else { Issue.record("Expected loaded"); return }; #expect(s.revenue.mrr == Money(2_000, "usd")) }
    @Test("keeps the previous snapshot on a network error") func networkKeepsOld() async { let api = ScriptedAPI(subscriptions: [subscription(1_000)]); let (c,_,_,cache) = system(api: api); await c.refresh(); let old = cache.snapshot; await api.setError(.network(underlying: TestFailure())); await c.refresh(); #expect(await c.phase == .stale(old, .network(underlying: TestFailure()))); #expect(cache.snapshot == old); #expect(cache.writeCount == 1) }
    @Test("goes to needsSetup on 401") func unauthorized() async throws { let api = ScriptedAPI(error: .unauthorized); let (c,keys,_,_) = system(api: api); await c.refresh(); #expect(await c.phase == .needsSetup); #expect(try keys.read() == key) }
    @Test("stays stale on 429 and does not clear the cache") func rateLimited() async { let old = oldSnapshot(); let api = ScriptedAPI(error: .rateLimited(retryAfter: 30)); let (c,_,_,cache) = system(api: api, cached: old); await c.refresh(); #expect(await c.phase == .stale(old, .rateLimited(retryAfter: 30))); #expect(cache.snapshot == old); #expect(cache.writeCount == 0) }
    @Test("shows a first-run failure with no snapshot") func firstFailure() async { let error = StripeError.network(underlying: TestFailure()); let api = ScriptedAPI(error: error); let (c,_,_,_) = system(api: api); await c.refresh(); #expect(await c.phase == .stale(nil, error)) }
    @Test("recovers to loaded when a later refresh succeeds") func recovery() async { let api = ScriptedAPI(error: .network(underlying: TestFailure())); let (c,_,_,_) = system(api: api); await c.refresh(); await api.setError(nil); await c.refresh(); guard case .loaded = await c.phase else { Issue.record("Expected loaded"); return } }
    @Test("carries on when only the products call fails") func productFallback() async { let api = ScriptedAPI(subscriptions: [subscription(1_000, product: "prod_fallback")], productsError: .network(underlying: TestFailure())); let (c,_,_,_) = system(api: api); await c.refresh(); guard case let .loaded(s) = await c.phase else { Issue.record("Expected loaded"); return }; #expect(s.revenue.breakdown.first?.name == "prod_fallback") }
    @Test("recomputes goals without any network call") func offlineGoals() async throws { let api = ScriptedAPI(subscriptions: [subscription(1_000)]); let (c,_,store,_) = system(api: api); await c.refresh(); let calls = await (api.subscriptionsCalls, api.transactionsCalls, api.productsCalls); _ = try store.add(name: "Second", targetDate: Date(iso: "2028-09-07T00:00:00Z"), targetAmount: nil); await c.recomputeGoals(); #expect(await (api.subscriptionsCalls, api.transactionsCalls, api.productsCalls) == calls); guard case let .loaded(s) = await c.phase else { Issue.record("Expected loaded"); return }; #expect(s.goals.count == 2) }
    @Test("recomputing keeps the original syncedAt") func keepsTime() async throws { let api = ScriptedAPI(); let (c,_,store,_) = system(api: api); await c.refresh(); guard case let .loaded(before) = await c.phase else { Issue.record("Expected loaded"); return }; _ = try store.add(name: "Second", targetDate: Date(iso: "2028-09-07T00:00:00Z"), targetAmount: nil); await c.recomputeGoals(); guard case let .loaded(after) = await c.phase else { Issue.record("Expected loaded"); return }; #expect(after.syncedAt == before.syncedAt) }
    @Test("recomputing with no cached revenue triggers a refresh instead") func recomputeRefreshes() async { let api = ScriptedAPI(); let (c,_,_,_) = system(api: api); await c.recomputeGoals(); #expect(await api.subscriptionsCalls == 1); guard case .loaded = await c.phase else { Issue.record("Expected loaded"); return } }
    @Test("goes to noGoals when the last goal is deleted") func deleteLast() async throws { let only = goal(); let api = ScriptedAPI(); let (c,_,store,_) = system(goals: [only], api: api); await c.refresh(); try store.delete(id: only.id); await c.recomputeGoals(); #expect(await c.phase == .noGoals) }
    @Test("two overlapping refreshes result in one set of fetches") func coalesces() async { let gate = Gate(); let api = ScriptedAPI(subscriptions: [subscription(1_000)], gate: gate); let (c,_,_,_) = system(api: api); let first = Task { await c.refresh() }; await gate.waitFor(3); let second = Task { await c.refresh() }; await Task.yield(); await gate.release(); await first.value; await second.value; #expect(await api.subscriptionsCalls == 1); #expect(await api.transactionsCalls == 1); #expect(await api.productsCalls == 1); guard case .loaded = await c.phase else { Issue.record("Expected loaded"); return } }
}
