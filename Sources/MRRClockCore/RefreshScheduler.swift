import Foundation

/// Schedules and cancels one-shot refresh work without exposing timer machinery to the core.
public protocol SchedulerDriver: Sendable {
    /// Installs one one-shot callback after the requested number of seconds.
    func schedule(after: TimeInterval, _ work: @escaping @Sendable () async -> Void)
    /// Invalidates the currently installed callback, if any.
    func cancel()
}

/// Starts automatic refresh work using the refresh interval configured under
/// `docs/ARCHITECTURE.md`'s state-machine boundary.
public actor RefreshScheduler {
    private let coordinator: RefreshCoordinator
    private let driver: any SchedulerDriver
    private let clock: any Clock
    private var config: Config
    private var isRunning = false
    private var failureCount = 0

    /// Creates a scheduler with injected refresh, timing, and clock dependencies.
    public init(
        coordinator: RefreshCoordinator,
        driver: any SchedulerDriver,
        clock: any Clock,
        config: Config
    ) {
        self.coordinator = coordinator
        self.driver = driver
        self.clock = clock
        self.config = config
    }

    /// Performs the initial refresh.
    public func start() async {
        isRunning = true
        await refreshAndSchedule()
    }

    /// Cancels automatic refresh work until the scheduler is started again.
    public func stop() {
        isRunning = false
        driver.cancel()
    }

    /// Applies a user-selected interval, enforcing the five-minute minimum.
    public func intervalChanged(to interval: TimeInterval) {
        config.refreshInterval = interval
        failureCount = 0
        guard isRunning else { return }
        driver.cancel()
        schedule(after: baseInterval)
    }

    /// Refreshes after wake when the retained snapshot is older than one interval.
    public func systemDidWake() async {
        guard isRunning, let snapshot = snapshot(from: await coordinator.phase),
              snapshot.isStale(now: clock.now, maxAge: baseInterval) else { return }
        await coordinator.refresh()
    }

    /// Retries immediately when connectivity returns from a stale state.
    public func networkDidReturn() async {
        guard isRunning, case .stale = await coordinator.phase else { return }
        await coordinator.refresh()
    }

    private func schedule(after delay: TimeInterval) {
        driver.schedule(after: delay) { [weak self] in
            await self?.timerFired()
        }
    }

    private var baseInterval: TimeInterval { max(config.refreshInterval, 300) }

    private func timerFired() async {
        guard isRunning else { return }
        await refreshAndSchedule()
    }

    private func refreshAndSchedule() async {
        await coordinator.refresh()
        guard isRunning else { return }
        let phase = await coordinator.phase
        let delay: TimeInterval
        switch phase {
        case let .stale(_, .rateLimited(retryAfter)):
            failureCount += 1
            delay = max(baseInterval, TimeInterval(retryAfter ?? 0))
        case .stale:
            failureCount += 1
            delay = min(baseInterval * pow(2, Double(failureCount)), 3600)
        default:
            failureCount = 0
            delay = baseInterval
        }
        schedule(after: delay)
    }

    private func snapshot(from phase: AppPhase) -> Snapshot? {
        switch phase {
        case let .loaded(snapshot), let .stale(snapshot?, _), let .loading(snapshot?): snapshot
        default: nil
        }
    }
}
