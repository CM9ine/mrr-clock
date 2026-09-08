import Combine
import Foundation

/// Main-actor presentation state that republishes `RefreshCoordinator` output for the app shell.
@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var phase: AppPhase = .idle

    private let coordinator: RefreshCoordinator?
    private let formatter: MenuBarFormatter
    private let titleFormat: TitleFormat
    private let clock: any Clock

    public init(
        coordinator: RefreshCoordinator? = nil,
        formatter: MenuBarFormatter = MenuBarFormatter(),
        titleFormat: TitleFormat = .daysAndMRR,
        clock: any Clock = SystemClock()
    ) {
        self.coordinator = coordinator
        self.formatter = formatter
        self.titleFormat = titleFormat
        self.clock = clock
    }

    /// The menu-bar string for the currently published phase.
    public var title: String {
        formatter.title(for: snapshot, phase: phase, format: titleFormat)
    }

    /// Goal progress values for the popover, with the pinned goal first.
    public var goalViewModels: [GoalProgress] {
        guard let goals = snapshot?.goals else { return [] }
        return goals.filter(\.isPinned) + goals.filter { !$0.isPinned }
    }

    /// Snapshot warnings displayed by the popover.
    public var warnings: [String] {
        snapshot?.revenue.warnings ?? []
    }

    /// The account-wide revenue values displayed by the popover.
    public var revenue: RevenueSnapshot? { snapshot?.revenue }

    /// The last successful synchronization instant displayed by the popover.
    public var syncedAt: Date? { snapshot?.syncedAt }

    /// The error carried by a stale phase, if any.
    public var staleError: StripeError? {
        guard case let .stale(_, error) = phase else { return nil }
        return error
    }

    /// Publishes a coordinator phase without adding presentation logic.
    public func publish(_ phase: AppPhase) {
        self.phase = phase
    }

    /// Loads cached state immediately and completes the coordinator's startup refresh.
    public func start() async {
        guard let coordinator else { return }
        let updates = await coordinator.phaseUpdates()
        let task = Task { await coordinator.start() }
        for await update in updates {
            publish(update)
            if update.isSettled { break }
        }
        await task.value
    }

    /// Performs a user-requested refresh and republishes its resulting phase.
    public func refresh() async {
        guard let coordinator else { return }
        let updates = await coordinator.phaseUpdates()
        let task = Task { await coordinator.refresh() }
        for await update in updates {
            publish(update)
            if update.isSettled { break }
        }
        await task.value
    }

    /// Pins a goal through the coordinator's offline goal-recalculation path.
    public func switchPinnedGoal(to id: UUID) async throws {
        guard let coordinator else { return }
        try await coordinator.pinGoal(id: id)
        publish(await coordinator.phase)
    }

    public func moneyLabel(_ money: Money) -> String { formatter.compactMoney(money) }
    public func daysLabel(_ days: Int) -> String { formatter.daysLabel(days) }
    public func percentLabel(_ ratio: Decimal?) -> String { formatter.percentLabel(ratio) }
    public var syncLabel: String? { syncedAt.map { formatter.relativeSync($0, now: clock.now) } }

    private var snapshot: Snapshot? {
        switch phase {
        case let .loading(previous), let .stale(previous, _): previous
        case let .loaded(snapshot): snapshot
        default: nil
        }
    }
}

private extension AppPhase {
    var isSettled: Bool {
        switch self {
        case .needsSetup, .noGoals, .loaded, .stale: true
        case .idle, .loading: false
        }
    }
}
