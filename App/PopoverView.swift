import MRRClockCore
import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            switch state.phase {
            case .idle, .loading(previous: nil):
                ProgressView()
            case .needsSetup:
                Button { openWindow(id: "settings") } label: { prompt("Add your Stripe key", systemImage: "key") }.buttonStyle(.plain)
            case .noGoals:
                Button { openWindow(id: "goals") } label: { prompt("Add your first goal", systemImage: "flag") }.buttonStyle(.plain)
            case .loading(previous: .some), .loaded:
                snapshotContent(dimmed: false)
            case .stale:
                snapshotContent(dimmed: true)
            }
        }
        .padding(16)
        .frame(width: 390)
    }

    private func prompt(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 120)
    }

    @ViewBuilder
    private func snapshotContent(dimmed: Bool) -> some View {
        if let goal = state.goalViewModels.first, let revenue = state.revenue {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(goal.name).font(.headline)
                    Spacer()
                    goalSwitcher(selected: goal)
                }
                HStack(spacing: 5) {
                    Text(goal.targetDate, style: .date)
                    Text("·")
                    Text(state.daysLabel(goal.daysRemaining))
                }
                .foregroundStyle(.secondary)

                Divider()
                metric("MRR", state.moneyLabel(revenue.mrr) + " /mo")
                metric("Earned to date", state.moneyLabel(revenue.earnedToDate))
                metric("Projected", state.moneyLabel(goal.projected))

                if goal.targetAmount != nil {
                    HStack {
                        ProgressView(value: bounded(goal.percentOnTrack))
                        Text(state.percentLabel(goal.percentOnTrack))
                            .monospacedDigit()
                    }
                }

                if !revenue.breakdown.isEmpty {
                    Divider()
                    HStack {
                        ForEach(revenue.breakdown, id: \.productID) { line in
                            VStack(alignment: .leading) {
                                Text(line.name).lineLimit(1)
                                Text(state.moneyLabel(line.amount)).foregroundStyle(.secondary)
                            }
                            if line.productID != revenue.breakdown.last?.productID { Spacer() }
                        }
                    }
                }

                if !state.warnings.isEmpty {
                    Divider()
                    ForEach(state.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if dimmed, let error = state.staleError {
                    Text("Refresh failed: \(String(describing: error))")
                        .foregroundStyle(.red)
                    Button("Retry") { Task { await state.refresh() } }
                }

                Divider()
                HStack {
                    Text(state.syncLabel.map { "Synced \($0)" } ?? "Not yet synced")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { Task { await state.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    Button("Goals") { openWindow(id: "goals") }
                        .buttonStyle(.plain)
                    Button { openWindow(id: "settings") } label: { Image(systemName: "gearshape") }
                        .buttonStyle(.plain)
                }
            }
            .opacity(dimmed ? 0.65 : 1)
        } else if dimmed {
            VStack(spacing: 12) {
                Text("Refresh failed")
                Button("Retry") { Task { await state.refresh() } }
            }
        }
    }

    private func goalSwitcher(selected: GoalProgress) -> some View {
        Menu {
            ForEach(state.goalViewModels, id: \.goalID) { goal in
                Button {
                    Task { try? await state.switchPinnedGoal(to: goal.goalID) }
                } label: {
                    if goal.goalID == selected.goalID {
                        Label(goal.name, systemImage: "checkmark")
                    } else {
                        Text(goal.name)
                    }
                }
            }
        } label: {
            Image(systemName: "chevron.down")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    private func bounded(_ ratio: Decimal?) -> Double {
        min(1, max(0, NSDecimalNumber(decimal: ratio ?? 0).doubleValue))
    }
}
