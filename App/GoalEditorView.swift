import MRRClockCore
import SwiftUI

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: GoalEditorModel
    @FocusState private var isNameFocused: Bool
    let onSave: (String, Date, Money?) throws -> Void

    init(goal: Goal? = nil, config: Config, revenue: RevenueSnapshot, clock: any Clock = SystemClock(), onSave: @escaping (String, Date, Money?) throws -> Void) {
        _model = State(initialValue: GoalEditorModel(goal: goal, config: config, revenue: revenue, clock: clock))
        self.onSave = onSave
    }

    var body: some View {
        Form {
            TextField("Name", text: $model.name)
                .accessibilityIdentifier("mrrclock.goal-name")
                .focused($isNameFocused)
            if model.targetDate == nil {
                Button("Choose target date") { model.targetDate = Calendar.current.startOfDay(for: SystemClock().now) }
            } else {
                DatePicker("Target date", selection: Binding(get: { model.targetDate! }, set: { model.targetDate = $0 }), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                Button("Clear date") { model.targetDate = nil }
            }
            TextField("Target amount (optional)", text: $model.amountText)
            if let message = model.validationMessage { Text(message).foregroundStyle(.red) }
            if model.targetDate == nil { Text("Choose a target date.").foregroundStyle(.red) }
            if let preview = model.preview {
                HStack {
                    Text(preview.days)
                    Text("· projected \(preview.projected.formatted(locale: .current))")
                    Text("· \(preview.percent) funded")
                }.foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .frame(minHeight: 560)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let date = model.targetDate else { return }
                    try? onSave(model.name, date, model.targetAmount)
                    dismiss()
                }
                .disabled(!model.canSave)
                .accessibilityIdentifier("mrrclock.goal-save")
            }
        }
        .onAppear { isNameFocused = true }
    }
}
