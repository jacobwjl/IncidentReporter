import SwiftUI
import SwiftData

// MARK: - Case Editor (Create / Edit)

struct CaseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let legalCase: LegalCase?
    let onSave: (LegalCase) -> Void

    @AppStorage("caseNumberPrefix") private var caseNumberPrefix = ""
    @AppStorage("autoGenerateReferenceNumbers") private var autoGenerateReferenceNumbers = false
    @AppStorage("referenceNumberFormat") private var referenceNumberFormat = "sequential"
    @AppStorage("referenceNumberSequentialCounter") private var referenceNumberSequentialCounter = 0
    @AppStorage("defaultCaseType") private var defaultCaseType = "General"
    @AppStorage("firmName") private var firmName = ""
    @AppStorage("showFirmNameInHeader") private var showFirmNameInHeader = true

    @State private var title = ""
    @State private var referenceNumber = ""
    @State private var selectedContext: ReportContext = .general
    @State private var notes = ""
    @State private var selectedStatus: CaseStatus = .open
    @State private var selectedPriority: CasePriority = .none

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(legalCase == nil ? "New Case" : "Edit Case")
                    .font(AppFonts.swiftUITitle)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(legalCase == nil ? "Create" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.isEmpty)
            }
            .padding()

            // Show firm name banner if enabled
            if showFirmNameInHeader && !firmName.isEmpty {
                HStack {
                    Image(systemName: "building.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(firmName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            Divider()

            Form {
                Section("Basics") {
                    TextField("Title", text: $title)

                    HStack {
                        TextField("Reference Number", text: $referenceNumber)
                        if legalCase == nil && autoGenerateReferenceNumbers && referenceNumber.isEmpty {
                            Button("Auto") {
                                referenceNumber = generateReferenceNumber()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    Picker("Type", selection: $selectedContext) {
                        ForEach(ReportContext.allCases) { ctx in
                            Text(ctx.rawValue).tag(ctx)
                        }
                    }
                }

                Section("Status & Priority") {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(CaseStatus.allCases) { status in
                            Label(status.rawValue, systemImage: status.icon).tag(status)
                        }
                    }

                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(CasePriority.allCases) { priority in
                            Label(priority.rawValue, systemImage: priority.icon).tag(priority)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Additional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 480, height: 500)
        .onAppear {
            if let legalCase {
                title = legalCase.title
                referenceNumber = legalCase.referenceNumber
                selectedContext = legalCase.context
                notes = legalCase.notes
                selectedStatus = legalCase.status
                selectedPriority = legalCase.priority
            } else {
                // Apply defaults for new cases
                if let ctx = ReportContext(rawValue: defaultCaseType) {
                    selectedContext = ctx
                }
                if autoGenerateReferenceNumbers {
                    referenceNumber = generateReferenceNumber()
                }
            }
        }
    }

    private func generateReferenceNumber() -> String {
        let nextNum = referenceNumberSequentialCounter + 1
        let prefix = caseNumberPrefix

        switch referenceNumberFormat {
        case "sequential":
            return "\(prefix)\(String(format: "%03d", nextNum))"
        case "dateBased":
            let year = Calendar.current.component(.year, from: Date.now)
            return "\(prefix)\(year)-\(String(format: "%03d", nextNum))"
        case "custom":
            return "\(prefix)\(String(format: "%03d", nextNum))"
        default:
            return "\(prefix)\(String(format: "%03d", nextNum))"
        }
    }

    private func save() {
        if let legalCase {
            legalCase.title = title
            legalCase.referenceNumber = referenceNumber
            legalCase.contextTypeRaw = selectedContext.rawValue
            legalCase.notes = notes
            if legalCase.status != selectedStatus {
                let old = legalCase.status
                legalCase.status = selectedStatus
                legalCase.addLogEntry("Status changed from \(old.rawValue) to \(selectedStatus.rawValue)", type: .statusChange)
            }
            legalCase.priority = selectedPriority
            legalCase.modifiedAt = .now
            onSave(legalCase)
        } else {
            let newCase = LegalCase(
                title: title,
                referenceNumber: referenceNumber,
                context: selectedContext,
                notes: notes,
                status: selectedStatus,
                priority: selectedPriority
            )
            // Increment the counter when auto-generating
            if autoGenerateReferenceNumbers && !referenceNumber.isEmpty {
                referenceNumberSequentialCounter += 1
            }
            onSave(newCase)
        }
        dismiss()
    }
}

// MARK: - Case Detail View

struct CaseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTags: [Tag]
    @Bindable var legalCase: LegalCase
    @Binding var selectedReport: Report?

    @State private var showingEditCase = false
    @State private var showingNewReport = false
    @State private var showingAddTag = false
    @State private var showingAddContact = false
    @State private var showingAddDeadline = false
    @State private var showAllActivity = false

    // New deadline inline fields
    @State private var newDeadlineTitle = ""
    @State private var newDeadlineDate = Date.now

    // New activity note
    @State private var showingAddNote = false
    @State private var newNoteText = ""

    // New tag creation
    @State private var newTagName = ""
    @State private var newTagColor: TagColor = .blue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: Header
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(legalCase.title.isEmpty ? "Untitled" : legalCase.title)
                            .font(AppFonts.swiftUITitle)
                            .textSelection(.enabled)
                        HStack(spacing: 8) {
                            Text(legalCase.context.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.blue.opacity(0.1))
                                .clipShape(Capsule())
                            if !legalCase.referenceNumber.isEmpty {
                                Text(legalCase.referenceNumber)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    Spacer()

                    Button {
                        legalCase.isStarred.toggle()
                        legalCase.modifiedAt = .now
                    } label: {
                        Image(systemName: legalCase.isStarred ? "star.fill" : "star")
                            .foregroundStyle(legalCase.isStarred ? .yellow : .secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help(legalCase.isStarred ? "Unstar" : "Star")

                    Button("Edit") { showingEditCase = true }
                }

                // MARK: Status & Priority Row
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: legalCase.status.icon)
                            .foregroundStyle(legalCase.status.color)
                            .font(.caption)
                        Picker("Status", selection: Binding(
                            get: { legalCase.status },
                            set: { newVal in
                                let old = legalCase.status
                                legalCase.status = newVal
                                legalCase.modifiedAt = .now
                                if old != newVal {
                                    legalCase.addLogEntry("Status changed from \(old.rawValue) to \(newVal.rawValue)", type: .statusChange)
                                }
                            }
                        )) {
                            ForEach(CaseStatus.allCases) { status in
                                Label(status.rawValue, systemImage: status.icon).tag(status)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }

                    HStack(spacing: 6) {
                        Image(systemName: legalCase.priority.icon)
                            .foregroundStyle(legalCase.priority.color)
                            .font(.caption)
                        Picker("Priority", selection: Binding(
                            get: { legalCase.priority },
                            set: { legalCase.priority = $0; legalCase.modifiedAt = .now }
                        )) {
                            ForEach(CasePriority.allCases) { p in
                                Label(p.rawValue, systemImage: p.icon).tag(p)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }

                    Spacer()
                }

                Divider()

                // MARK: Custom Fields
                if !legalCase.sortedFields.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(AppFonts.swiftUIHeading)

                        ForEach(legalCase.sortedFields) { field in
                            HStack(alignment: .top) {
                                TextField("Label", text: Binding(
                                    get: { field.label },
                                    set: { field.label = $0; legalCase.modifiedAt = .now }
                                ))
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(width: 130, alignment: .trailing)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)

                                TextField("Value", text: Binding(
                                    get: { field.value },
                                    set: { field.value = $0; legalCase.modifiedAt = .now }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        }

                        Button {
                            let field = CaseField(label: "", value: "", order: legalCase.fields.count)
                            field.legalCase = legalCase
                            legalCase.fields.append(field)
                        } label: {
                            Label("Add Field", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                } else {
                    Button {
                        let field = CaseField(label: "Field", value: "", order: 0)
                        field.legalCase = legalCase
                        legalCase.fields.append(field)
                    } label: {
                        Label("Add Detail Fields", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                }

                // MARK: Notes
                if !legalCase.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(legalCase.notes)
                            .textSelection(.enabled)
                    }
                }

                Divider()

                // MARK: Tags Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Tags")
                            .font(AppFonts.swiftUIHeading)
                        Spacer()
                        Button {
                            showingAddTag.toggle()
                        } label: {
                            Label("Add Tag", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .popover(isPresented: $showingAddTag, arrowEdge: .bottom) {
                            addTagPopover
                        }
                    }

                    if legalCase.tags.isEmpty {
                        Text("No tags")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        FlowLayout(spacing: 6) {
                            ForEach(legalCase.tags) { tag in
                                TagPill(tag: tag) {
                                    legalCase.tags.removeAll { $0.id == tag.id }
                                    legalCase.modifiedAt = .now
                                }
                            }
                        }
                    }
                }

                Divider()

                // MARK: Deadlines Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Deadlines")
                            .font(AppFonts.swiftUIHeading)
                        Spacer()
                        Button {
                            showingAddDeadline.toggle()
                        } label: {
                            Label("Add Deadline", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }

                    if legalCase.sortedDeadlines.isEmpty && !showingAddDeadline {
                        Text("No deadlines")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(legalCase.sortedDeadlines) { deadline in
                            HStack(spacing: 8) {
                                Button {
                                    deadline.isCompleted.toggle()
                                    legalCase.modifiedAt = .now
                                    let action = deadline.isCompleted ? "completed" : "reopened"
                                    legalCase.addLogEntry("Deadline \"\(deadline.title)\" \(action)", type: .milestone)
                                } label: {
                                    Image(systemName: deadline.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(deadline.urgencyColor)
                                        .font(.body)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(deadline.title.isEmpty ? "Untitled" : deadline.title)
                                        .font(.body)
                                        .strikethrough(deadline.isCompleted)
                                        .foregroundStyle(deadline.isCompleted ? .secondary : .primary)
                                    HStack(spacing: 6) {
                                        Text(deadline.dueDate.shortLegal)
                                            .font(.caption)
                                            .foregroundStyle(deadline.isOverdue ? .red : .secondary)
                                        if deadline.isOverdue {
                                            Text("OVERDUE")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.red)
                                        } else if deadline.isDueSoon {
                                            Text("DUE SOON")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }

                                Spacer()

                                Image(systemName: deadline.urgencyIcon)
                                    .font(.caption)
                                    .foregroundStyle(deadline.urgencyColor)
                            }
                            .padding(.vertical, 4)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    legalCase.deadlines.removeAll { $0.id == deadline.id }
                                    modelContext.delete(deadline)
                                    legalCase.modifiedAt = .now
                                }
                            }
                        }
                    }

                    // Inline new deadline
                    if showingAddDeadline {
                        VStack(alignment: .leading, spacing: 6) {
                            Divider()
                            HStack(spacing: 8) {
                                TextField("Deadline title", text: $newDeadlineTitle)
                                    .textFieldStyle(.roundedBorder)
                                DatePicker("", selection: $newDeadlineDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .fixedSize()
                                Button("Add") {
                                    guard !newDeadlineTitle.isEmpty else { return }
                                    let deadline = Deadline(title: newDeadlineTitle, dueDate: newDeadlineDate)
                                    deadline.legalCase = legalCase
                                    legalCase.deadlines.append(deadline)
                                    legalCase.modifiedAt = .now
                                    legalCase.addLogEntry("Deadline added: \(newDeadlineTitle)", type: .milestone)
                                    newDeadlineTitle = ""
                                    newDeadlineDate = .now
                                    showingAddDeadline = false
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(newDeadlineTitle.isEmpty)

                                Button("Cancel") {
                                    newDeadlineTitle = ""
                                    newDeadlineDate = .now
                                    showingAddDeadline = false
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                Divider()

                // MARK: Contacts Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Contacts")
                            .font(AppFonts.swiftUIHeading)
                        Spacer()
                        Button {
                            showingAddContact = true
                        } label: {
                            Label("Add Contact", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }

                    if legalCase.contacts.isEmpty {
                        Text("No contacts")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(legalCase.contacts) { contact in
                            HStack(spacing: 10) {
                                Image(systemName: "person.circle")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.name.isEmpty ? "Unnamed" : contact.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    HStack(spacing: 8) {
                                        if !contact.role.isEmpty {
                                            Text(contact.role)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if !contact.organization.isEmpty {
                                            Text(contact.organization)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    HStack(spacing: 8) {
                                        if !contact.email.isEmpty {
                                            Text(contact.email)
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                        }
                                        if !contact.phone.isEmpty {
                                            Text(contact.phone)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .contextMenu {
                                Button("Edit") {
                                    // Re-open the contact sheet would require more state;
                                    // for now contacts can be deleted and re-added
                                }
                                Button("Delete", role: .destructive) {
                                    legalCase.contacts.removeAll { $0.id == contact.id }
                                    modelContext.delete(contact)
                                    legalCase.modifiedAt = .now
                                }
                            }
                        }
                    }
                }

                Divider()

                // MARK: Case Files
                CaseFilesView(legalCase: legalCase)

                Divider()

                // MARK: Reports
                HStack {
                    Text("Reports")
                        .font(AppFonts.swiftUITitle)
                    Spacer()
                    Button("New Report") { showingNewReport = true }
                        .keyboardShortcut("n", modifiers: [.command, .shift])
                }

                if legalCase.reports.isEmpty {
                    VStack(spacing: 12) {
                        Text("No reports yet")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 180, maximum: 260))
                    ], spacing: 12) {
                        ForEach(legalCase.reports.sorted(by: { $0.modifiedAt > $1.modifiedAt })) { report in
                            ReportCard(report: report) {
                                selectedReport = report
                            }
                        }
                    }
                }

                // Quick create
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Create")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(ReportContext.allCases) { ctx in
                            Button(ctx.rawValue) {
                                let report = Report(title: ctx.rawValue, context: ctx)
                                report.legalCase = legalCase
                                legalCase.reports.append(report)
                                legalCase.modifiedAt = .now
                                selectedReport = report
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                Divider()

                // MARK: Activity Log
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Activity Log")
                            .font(AppFonts.swiftUIHeading)
                        Spacer()

                        Button {
                            showingAddNote.toggle()
                        } label: {
                            Label("Add Note", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }

                    // Inline add note
                    if showingAddNote {
                        HStack(spacing: 8) {
                            TextField("Activity note...", text: $newNoteText)
                                .textFieldStyle(.roundedBorder)
                            Button("Add") {
                                guard !newNoteText.isEmpty else { return }
                                legalCase.addLogEntry(newNoteText, type: .note)
                                legalCase.modifiedAt = .now
                                newNoteText = ""
                                showingAddNote = false
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(newNoteText.isEmpty)
                            Button("Cancel") {
                                newNoteText = ""
                                showingAddNote = false
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .controlSize(.small)
                        }
                        .padding(.bottom, 4)
                    }

                    let sortedLog = legalCase.sortedActivityLog
                    let displayedLog = showAllActivity ? sortedLog : Array(sortedLog.prefix(10))

                    if displayedLog.isEmpty {
                        Text("No activity logged")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(Array(displayedLog.enumerated()), id: \.element.persistentModelID) { index, entry in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(spacing: 0) {
                                    Image(systemName: entry.entryType.icon)
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        .frame(width: 20, height: 20)
                                    if index < displayedLog.count - 1 {
                                        Rectangle()
                                            .fill(.quaternary)
                                            .frame(width: 1)
                                            .frame(minHeight: 8, maxHeight: 40)
                                    }
                                }
                                .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.message)
                                        .font(.body)
                                    HStack(spacing: 6) {
                                        Text(entry.entryType.rawValue)
                                            .font(.caption2)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(.blue.opacity(0.08))
                                            .clipShape(Capsule())
                                        Text(entry.timestamp.relativeFormatted)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.bottom, 8)

                                Spacer()
                            }
                        }

                        if sortedLog.count > 10 {
                            Button(showAllActivity ? "Show Less" : "Show All (\(sortedLog.count))") {
                                withAnimation { showAllActivity.toggle() }
                            }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 860)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingEditCase) {
            CaseEditorView(legalCase: legalCase) { _ in }
        }
        .sheet(isPresented: $showingNewReport) {
            NewReportSheet(legalCase: legalCase) { report in
                selectedReport = report
            }
        }
        .sheet(isPresented: $showingAddContact) {
            AddContactSheet(legalCase: legalCase)
        }
    }

    // MARK: - Add Tag Popover

    @ViewBuilder
    private var addTagPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Tag")
                .font(.system(size: 13, weight: .semibold))

            // Existing tags not already on this case
            let availableTags = allTags.filter { tag in
                !legalCase.tags.contains(where: { $0.id == tag.id })
            }

            if !availableTags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Existing Tags")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 4) {
                        ForEach(availableTags) { tag in
                            Button {
                                legalCase.tags.append(tag)
                                legalCase.modifiedAt = .now
                                showingAddTag = false
                            } label: {
                                TagPill(tag: tag)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Create New Tag")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Tag name", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                HStack(spacing: 4) {
                    ForEach(TagColor.allCases) { tc in
                        Button {
                            newTagColor = tc
                        } label: {
                            Circle()
                                .fill(tc.color)
                                .frame(width: 18, height: 18)
                                .overlay {
                                    if newTagColor == tc {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button("Create & Add") {
                    guard !newTagName.isEmpty else { return }
                    let tag = Tag(name: newTagName, colorHex: newTagColor.hex)
                    modelContext.insert(tag)
                    legalCase.tags.append(tag)
                    legalCase.modifiedAt = .now
                    newTagName = ""
                    newTagColor = .blue
                    showingAddTag = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(newTagName.isEmpty)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}

// MARK: - Add Contact Sheet

struct AddContactSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let legalCase: LegalCase

    @State private var name = ""
    @State private var role = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var organization = ""
    @State private var notes = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Contact")
                    .font(AppFonts.swiftUITitle)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { addContact() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("Contact Information") {
                    TextField("Name", text: $name)
                    TextField("Role", text: $role)
                    TextField("Email", text: $email)
                    TextField("Phone", text: $phone)
                    TextField("Organization", text: $organization)
                }

                Section("Notes") {
                    TextField("Additional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 420, height: 380)
    }

    private func addContact() {
        let contact = Contact(
            name: name,
            role: role,
            email: email,
            phone: phone,
            organization: organization,
            notes: notes
        )
        contact.legalCase = legalCase
        legalCase.contacts.append(contact)
        legalCase.modifiedAt = .now
        legalCase.addLogEntry("Contact added: \(name)", type: .communication)
        dismiss()
    }
}

// MARK: - Report Card

struct ReportCard: View {
    let report: Report
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text(report.title.isEmpty ? "Untitled" : report.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(report.modifiedAt.shortLegal)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - New Report Sheet

struct NewReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let legalCase: LegalCase
    let onCreated: (Report) -> Void

    @AppStorage("defaultPreparedBy") private var defaultPreparedBy = ""
    @AppStorage("defaultTitleFormat") private var defaultTitleFormat = "{type} - {date}"
    @AppStorage("defaultConfidentialityNotice") private var defaultConfidentialityNotice = ""
    @AppStorage("defaultBatesPrefix") private var defaultBatesPrefix = ""
    @AppStorage("autoNumberReports") private var autoNumberReports = false
    @AppStorage("autoNumberCounter") private var autoNumberCounter = 0

    @State private var title = ""
    @State private var selectedContext: ReportContext = .general
    @State private var preparedBy = ""
    @State private var confidentialityNotice = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Report")
                    .font(AppFonts.swiftUITitle)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            Form {
                Section("Report") {
                    TextField("Report Title", text: $title)
                    Picker("Type", selection: $selectedContext) {
                        ForEach(ReportContext.allCases) { ctx in
                            Text(ctx.rawValue).tag(ctx)
                        }
                    }
                }

                Section("Details") {
                    TextField("Prepared By", text: $preparedBy)
                    TextField("Confidentiality Notice", text: $confidentialityNotice)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 420, height: 340)
        .onAppear {
            selectedContext = legalCase.context
            // Apply defaults
            if !defaultPreparedBy.isEmpty && preparedBy.isEmpty {
                preparedBy = defaultPreparedBy
            }
            if !defaultConfidentialityNotice.isEmpty && confidentialityNotice.isEmpty {
                confidentialityNotice = defaultConfidentialityNotice
            }
            // Generate default title from format
            if title.isEmpty {
                title = buildDefaultTitle()
            }
        }
    }

    private func buildDefaultTitle() -> String {
        var result = defaultTitleFormat
        result = result.replacingOccurrences(of: "{type}", with: legalCase.context.rawValue)
        result = result.replacingOccurrences(of: "{date}", with: Date.now.shortLegal)
        result = result.replacingOccurrences(of: "{case}", with: legalCase.title)
        if autoNumberReports {
            result += " Report #\(autoNumberCounter + 1)"
        }
        return result
    }

    private func create() {
        let reportTitle = title.isEmpty ? selectedContext.rawValue : title
        let report = Report(
            title: reportTitle,
            context: selectedContext,
            preparedBy: preparedBy
        )
        report.confidentialityNotice = confidentialityNotice
        if !defaultBatesPrefix.isEmpty {
            report.batesPrefix = defaultBatesPrefix
        }
        report.legalCase = legalCase
        legalCase.reports.append(report)
        legalCase.modifiedAt = .now
        // Increment auto-number counter
        if autoNumberReports {
            autoNumberCounter += 1
        }
        onCreated(report)
        dismiss()
    }
}
