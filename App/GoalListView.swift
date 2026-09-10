import MRRClockCore
import SwiftUI
import UniformTypeIdentifiers

struct GoalListView: View {
    let store: GoalStore
    let config: Config
    let revenue: RevenueSnapshot
    let didChange: () -> Void
    @State private var goals: [Goal] = []
    @State private var editing: Goal?
    @State private var adding = false
    @State private var pendingDelete: Goal?
    @State private var draggedGoalID: UUID?

    var body: some View {
        List {
            ForEach(goals) { goal in
                HStack {
                    Button { try? store.pin(id: goal.id); reload() } label: {
                        Image(systemName: store.pinned?.id == goal.id ? "pin.fill" : "pin")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pin \(goal.name)")
                    .accessibilityValue(store.pinned?.id == goal.id ? "pinned" : "not pinned")
                    .accessibilityIdentifier("mrrclock.goal-pin.\(goal.id.uuidString)")
                    VStack(alignment: .leading) {
                        Text(goal.name)
                        Text(daysLabel(goal.targetDate)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(goal.targetDate, style: .date).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .accessibilityElement(children: .contain)
                .accessibilityLabel(goal.name)
                .accessibilityIdentifier("mrrclock.goal-row.\(goal.id.uuidString)")
                .onDrag {
                    draggedGoalID = goal.id
                    return NSItemProvider(object: goal.id.uuidString as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: GoalRowDropDelegate(
                        destination: goal,
                        draggedGoalID: $draggedGoalID,
                        goals: goals,
                        store: store,
                        reload: reload
                    )
                )
                .onTapGesture { editing = goal }
                .swipeActions { Button("Delete", role: .destructive) { pendingDelete = goal } }
            }
            .onMove { from, to in try? store.move(from: from, to: to); reload() }
            .onDelete { offsets in if let first = offsets.first { pendingDelete = goals[first] } }
        }
        .navigationTitle("Goals")
        .toolbar {
            Button { adding = true } label: { Image(systemName: "plus") }
                .accessibilityIdentifier("mrrclock.add-goal")
        }
        .onAppear(perform: reload)
        .sheet(isPresented: $adding) { NavigationStack { editor(nil) } }
        .sheet(item: $editing) { goal in NavigationStack { editor(goal) } }
        .confirmationDialog("Delete this goal?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete", role: .destructive) { if let goal = pendingDelete { try? store.delete(id: goal.id); reload() }; pendingDelete = nil }
        }
    }

    private func editor(_ goal: Goal?) -> some View {
        GoalEditorView(goal: goal, config: config, revenue: revenue) { name, date, amount in
            if var goal { goal.name = name; goal.targetDate = date; goal.targetAmount = amount; try store.update(goal) }
            else { try store.add(name: name, targetDate: date, targetAmount: amount) }
            reload()
        }
    }

    private func reload() { goals = store.goals; didChange() }
    private func daysLabel(_ date: Date) -> String {
        let days = Countdown.daysRemaining(now: SystemClock().now, target: date)
        if days < 0 { return "\(-days) days overdue" }
        if days == 0 { return "today" }
        return "\(days) days remaining"
    }
}

private struct GoalRowDropDelegate: DropDelegate {
    let destination: Goal
    @Binding var draggedGoalID: UUID?
    let goals: [Goal]
    let store: GoalStore
    let reload: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard
            let sourceID = draggedGoalID,
            let source = goals.firstIndex(where: { $0.id == sourceID }),
            let target = goals.firstIndex(where: { $0.id == destination.id }),
            source != target
        else { return false }
        do {
            try store.move(from: IndexSet(integer: source), to: target)
            reload()
        } catch {
            return false
        }
        draggedGoalID = nil
        return true
    }
}
