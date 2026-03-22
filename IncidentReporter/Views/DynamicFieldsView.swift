import SwiftUI
import SwiftData

struct DynamicFieldsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var incident: Incident

    private var theme: CategoryTheme { incident.context.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(AppFonts.swiftUIHeading)
                .foregroundStyle(theme.accentColor)

            if !incident.sortedFields.isEmpty {
                ForEach(incident.sortedFields) { field in
                    fieldRow(field)
                }

                Button {
                    let field = IncidentField(label: "", value: "", order: incident.fields.count)
                    field.incident = incident
                    incident.fields.append(field)
                    incident.modifiedAt = .now
                } label: {
                    Label("Add Field", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accentColor)
            } else {
                Button {
                    resetToDefaults()
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Field Row

    @ViewBuilder
    private func fieldRow(_ field: IncidentField) -> some View {
        HStack(alignment: .center, spacing: 4) {
            // Reorder buttons
            VStack(spacing: 0) {
                Button {
                    moveField(field, direction: .up)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .medium))
                        .frame(width: 16, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(field.order == 0)

                Button {
                    moveField(field, direction: .down)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .frame(width: 16, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(field.order >= incident.fields.count - 1)
            }

            // Label
            TextField("Label", text: Binding(
                get: { field.label },
                set: { field.label = $0; incident.modifiedAt = .now }
            ))
            .font(.caption)
            .fontWeight(.medium)
            .frame(width: 130, alignment: .trailing)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)

            // Value
            TextField("Value", text: Binding(
                get: { field.value },
                set: { field.value = $0; incident.modifiedAt = .now }
            ))
            .textFieldStyle(.roundedBorder)

            // Delete button
            Button {
                deleteField(field)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private enum MoveDirection { case up, down }

    private func moveField(_ field: IncidentField, direction: MoveDirection) {
        let sorted = incident.sortedFields
        guard let index = sorted.firstIndex(where: { $0.id == field.id }) else { return }

        let swapIndex: Int
        switch direction {
        case .up:
            guard index > 0 else { return }
            swapIndex = index - 1
        case .down:
            guard index < sorted.count - 1 else { return }
            swapIndex = index + 1
        }

        let other = sorted[swapIndex]
        let tempOrder = field.order
        field.order = other.order
        other.order = tempOrder
        incident.modifiedAt = .now
    }

    private func deleteField(_ field: IncidentField) {
        incident.fields.removeAll { $0.id == field.id }
        modelContext.delete(field)

        // Recalculate order indices
        for (i, f) in incident.sortedFields.enumerated() {
            f.order = i
        }
        incident.modifiedAt = .now
    }

    private func resetToDefaults() {
        let defaults = incident.context.defaultFieldLabels
        for (i, pair) in defaults.enumerated() {
            let field = IncidentField(label: pair.0, value: pair.1, order: i)
            field.incident = incident
            incident.fields.append(field)
        }

        // If category has no defaults, add one blank field
        if defaults.isEmpty {
            let field = IncidentField(label: "Field", value: "", order: 0)
            field.incident = incident
            incident.fields.append(field)
        }

        incident.modifiedAt = .now
    }
}
