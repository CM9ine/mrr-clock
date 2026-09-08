import MRRClockCore
import SwiftUI

struct GoalListView: View {
    let store: GoalStore
    let config: Config
    let revenue: RevenueSnapshot
    let didChange: () -> Void
    @State private var goals: [Goal] = []
    @State private var editing: Goal?
    @State private var adding = false
    @State private var pendingDelete: Goal?

    var body: some View {
        List {
            ForEach(goals) { goal in
                HStack {
                    Button { try? store.pin(id: goal.id); reload() } label: {
                        Image(systemName: store.pinned?.id == goal.id ? "pin.fill" : "pin")
                    }.buttonStyle(.plain)
                    VStack(alignment: .leading) {
                        Text(goal.name)
                        Text(daysLabel(goal.targetDate)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(goal.targetDate, style: .date).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { editing = goal }
                .swipeActions { Button("Delete", role: .destructive) { pendingDelete = goal } }
            }
            .onMove { from, to in try? store.move(from: from, to: to); reload() }
            .onDelete { offsets in if let first = offsets.first { pendingDelete = goals[first] } }
        }
        .navigationTitle("Goals")
        .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
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
