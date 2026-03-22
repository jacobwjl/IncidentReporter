import SwiftUI
import SwiftData

// MARK: - Incident Editor (Create / Edit)

struct IncidentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let incident: Incident?
    let onSave: (Incident) -> Void

    @AppStorage("incidentNumberPrefix") private var incidentNumberPrefix = ""
    @AppStorage("autoGenerateReferenceNumbers") private var autoGenerateReferenceNumbers = false
    @AppStorage("referenceNumberFormat") private var referenceNumberFormat = "sequential"
    @AppStorage("referenceNumberSequentialCounter") private var referenceNumberSequentialCounter = 0
    @AppStorage("defaultIncidentCategory") private var defaultIncidentCategory = "General"
    @AppStorage("orgName") private var orgName = ""
    @AppStorage("showOrgNameInHeader") private var showOrgNameInHeader = true

    @State private var title = ""
    @State private var referenceNumber = ""
    @State private var selectedContext: IncidentCategory = .general
    @State private var notes = ""
    @State private var selectedStatus: IncidentStatus = .open
    @State private var selectedSeverity: Severity = .none
    @State private var location = ""
    @State private var selectedSource: IncidentSource = .inPerson

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(incident == nil ? "New Incident" : "Edit Incident")
                    .font(AppFonts.swiftUITitle)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.small)
                Button(incident == nil ? "Create" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
                    .disabled(title.isEmpty)
            }
            .padding()

            // Show organization name banner if enabled
            if showOrgNameInHeader && !orgName.isEmpty {
                HStack {
                    Image(systemName: "building.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(orgName)
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
                        if incident == nil && autoGenerateReferenceNumbers && referenceNumber.isEmpty {
                            Button("Auto") {
                                referenceNumber = generateReferenceNumber()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    Picker("Type", selection: $selectedContext) {
                        ForEach(IncidentCategory.allCases) { ctx in
                            Text(ctx.rawValue).tag(ctx)
                        }
                    }

                    TextField("Location", text: $location)

                    Picker("Source", selection: $selectedSource) {
                        ForEach(IncidentSource.allCases) { source in
                            Label(source.rawValue, systemImage: source.icon).tag(source)
                        }
                    }
                }

                Section("Status & Severity") {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(IncidentStatus.allCases) { status in
                            Label(status.rawValue, systemImage: status.icon).tag(status)
                        }
                    }

                    Picker("Severity", selection: $selectedSeverity) {
                        ForEach(Severity.allCases) { severity in
                            Label(severity.rawValue, systemImage: severity.icon).tag(severity)
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
        .frame(width: 440, height: 520)
        .onAppear {
            if let incident {
                title = incident.title
                referenceNumber = incident.referenceNumber
                selectedContext = incident.context
                notes = incident.notes
                selectedStatus = incident.status
                selectedSeverity = incident.priority
                location = incident.location
                selectedSource = incident.source
            } else {
                // Apply defaults for new incidents
                if let ctx = IncidentCategory(rawValue: defaultIncidentCategory) {
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
        let prefix = incidentNumberPrefix

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
        if let incident {
            incident.title = title
            incident.referenceNumber = referenceNumber
            incident.contextTypeRaw = selectedContext.rawValue
            incident.notes = notes
            if incident.status != selectedStatus {
                let old = incident.status
                incident.status = selectedStatus
                incident.addLogEntry("Status changed from \(old.rawValue) to \(selectedStatus.rawValue)", type: .statusChange)
            }
            incident.priority = selectedSeverity
            incident.location = location
            incident.source = selectedSource
            incident.modifiedAt = .now
            onSave(incident)
        } else {
            let newIncident = Incident(
                title: title,
                referenceNumber: referenceNumber,
                context: selectedContext,
                notes: notes,
                status: selectedStatus,
                priority: selectedSeverity,
                location: location,
                source: selectedSource
            )
            // Increment the counter when auto-generating
            if autoGenerateReferenceNumbers && !referenceNumber.isEmpty {
                referenceNumberSequentialCounter += 1
            }
            onSave(newIncident)
        }
        dismiss()
    }
}

// MARK: - Incident Detail View

struct IncidentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTags: [Tag]
    @Bindable var incident: Incident
    @Binding var selectedReport: Report?

    @State private var showingEditIncident = false
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
            VStack(alignment: .leading, spacing: 20) {
                // MARK: Header
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(incident.title.isEmpty ? "Untitled" : incident.title)
                            .font(AppFonts.swiftUITitle)
                            .textSelection(.enabled)
                        HStack(spacing: 8) {
                            Text(incident.context.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(incident.context.theme.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                            if !incident.referenceNumber.isEmpty {
                                Text(incident.referenceNumber)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    Spacer()

                    Button {
                        incident.isStarred.toggle()
                        incident.modifiedAt = .now
                    } label: {
                        Image(systemName: incident.isStarred ? "star.fill" : "star")
                            .foregroundStyle(incident.isStarred ? .yellow : .secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help(incident.isStarred ? "Unstar" : "Star")

                    Button("Edit") { showingEditIncident = true }
                        .controlSize(.small)
                }

                // MARK: Location & Source
                if !incident.location.isEmpty || incident.source != .inPerson {
                    HStack(spacing: 16) {
                        if !incident.location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                Text(incident.location)
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                        }
                        HStack(spacing: 4) {
                            Image(systemName: incident.source.icon)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(incident.source.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                // MARK: Status & Severity Row
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: incident.status.icon)
                            .foregroundStyle(incident.status.color)
                            .font(.caption)
                        Picker("Status", selection: Binding(
                            get: { incident.status },
                            set: { newVal in
                                let old = incident.status
                                incident.status = newVal
                                incident.modifiedAt = .now
                                if old != newVal {
                                    incident.addLogEntry("Status changed from \(old.rawValue) to \(newVal.rawValue)", type: .statusChange)
                                }
                            }
                        )) {
                            ForEach(IncidentStatus.allCases) { status in
                                Label(status.rawValue, systemImage: status.icon).tag(status)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }

                    HStack(spacing: 6) {
                        Image(systemName: incident.priority.icon)
                            .foregroundStyle(incident.priority.color)
                            .font(.caption)
                        Picker("Severity", selection: Binding(
                            get: { incident.priority },
                            set: { incident.priority = $0; incident.modifiedAt = .now }
                        )) {
                            ForEach(Severity.allCases) { p in
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
                DynamicFieldsView(incident: incident)

                // MARK: Notes
                if !incident.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(incident.notes)
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
                        .foregroundStyle(incident.context.theme.accentColor)
                        .popover(isPresented: $showingAddTag, arrowEdge: .bottom) {
                            addTagPopover
                        }
                    }

                    if incident.tags.isEmpty {
                        Text("No tags")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        FlowLayout(spacing: 6) {
                            ForEach(incident.tags) { tag in
                                TagPill(tag: tag) {
                                    incident.tags.removeAll { $0.id == tag.id }
                                    incident.modifiedAt = .now
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
                        .foregroundStyle(incident.context.theme.accentColor)
                    }

                    if incident.sortedDeadlines.isEmpty && !showingAddDeadline {
                        Text("No deadlines")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(incident.sortedDeadlines) { deadline in
                            HStack(spacing: 8) {
                                Button {
                                    deadline.isCompleted.toggle()
                                    incident.modifiedAt = .now
                                    let action = deadline.isCompleted ? "completed" : "reopened"
                                    incident.addLogEntry("Deadline \"\(deadline.title)\" \(action)", type: .milestone)
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
                                        Text(deadline.dueDate.shortFormatted)
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
                                    incident.deadlines.removeAll { $0.id == deadline.id }
                                    modelContext.delete(deadline)
                                    incident.modifiedAt = .now
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
                                    deadline.incident = incident
                                    incident.deadlines.append(deadline)
                                    incident.modifiedAt = .now
                                    incident.addLogEntry("Deadline added: \(newDeadlineTitle)", type: .milestone)
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
                        .foregroundStyle(incident.context.theme.accentColor)
                    }

                    if incident.contacts.isEmpty {
                        Text("No contacts")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(incident.contacts) { contact in
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
                                    incident.contacts.removeAll { $0.id == contact.id }
                                    modelContext.delete(contact)
                                    incident.modifiedAt = .now
                                }
                            }
                        }
                    }
                }

                Divider()

                // MARK: Incident Files
                IncidentFilesView(incident: incident)

                Divider()

                // MARK: Reports
                HStack {
                    Text("Reports")
                        .font(AppFonts.swiftUITitle)
                    Spacer()
                    Button("New Report") { showingNewReport = true }
                        .keyboardShortcut("n", modifiers: [.command, .shift])
                        .controlSize(.small)
                }

                if incident.reports.isEmpty {
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
                        ForEach(incident.reports.sorted(by: { $0.modifiedAt > $1.modifiedAt })) { report in
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
                        ForEach(IncidentCategory.allCases) { ctx in
                            Button(ctx.rawValue) {
                                let report = Report(title: ctx.rawValue, context: ctx)
                                report.incident = incident
                                incident.reports.append(report)
                                incident.modifiedAt = .now
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
                        .foregroundStyle(incident.context.theme.accentColor)
                    }

                    // Inline add note
                    if showingAddNote {
                        HStack(spacing: 8) {
                            TextField("Activity note...", text: $newNoteText)
                                .textFieldStyle(.roundedBorder)
                            Button("Add") {
                                guard !newNoteText.isEmpty else { return }
                                incident.addLogEntry(newNoteText, type: .note)
                                incident.modifiedAt = .now
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

                    let sortedLog = incident.sortedActivityLog
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
                                        .foregroundStyle(incident.context.theme.accentColor)
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
                                            .background(incident.context.theme.accentColor.opacity(0.08))
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
                            .foregroundStyle(incident.context.theme.accentColor)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 760)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingEditIncident) {
            IncidentEditorView(incident: incident) { _ in }
        }
        .sheet(isPresented: $showingNewReport) {
            NewReportSheet(incident: incident) { report in
                selectedReport = report
            }
        }
        .sheet(isPresented: $showingAddContact) {
            AddContactSheet(incident: incident)
        }
    }

    // MARK: - Add Tag Popover

    @ViewBuilder
    private var addTagPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Tag")
                .font(.system(size: 13, weight: .semibold))

            // Existing tags not already on this incident
            let availableTags = allTags.filter { tag in
                !incident.tags.contains(where: { $0.id == tag.id })
            }

            if !availableTags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Existing Tags")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 4) {
                        ForEach(availableTags) { tag in
                            Button {
                                incident.tags.append(tag)
                                incident.modifiedAt = .now
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
                    incident.tags.append(tag)
                    incident.modifiedAt = .now
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
    let incident: Incident

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
                    .controlSize(.small)
                Button("Add") { addContact() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
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
        contact.incident = incident
        incident.contacts.append(contact)
        incident.modifiedAt = .now
        incident.addLogEntry("Contact added: \(name)", type: .communication)
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
                    .foregroundStyle(report.context.theme.accentColor)
                Text(report.title.isEmpty ? "Untitled" : report.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(report.modifiedAt.shortFormatted)
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
    let incident: Incident
    let onCreated: (Report) -> Void

    @AppStorage("defaultReportedBy") private var defaultReportedBy = ""
    @AppStorage("defaultTitleFormat") private var defaultTitleFormat = "{type} - {date}"
    @AppStorage("defaultConfidentialityNotice") private var defaultConfidentialityNotice = ""
    @AppStorage("defaultBatesPrefix") private var defaultBatesPrefix = ""
    @AppStorage("autoNumberReports") private var autoNumberReports = false
    @AppStorage("autoNumberCounter") private var autoNumberCounter = 0

    @State private var title = ""
    @State private var selectedContext: IncidentCategory = .general
    @State private var reportedBy = ""
    @State private var confidentialityNotice = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Report")
                    .font(AppFonts.swiftUITitle)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.small)
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
            }
            .padding()

            Divider()

            Form {
                Section("Report") {
                    TextField("Report Title", text: $title)
                    Picker("Type", selection: $selectedContext) {
                        ForEach(IncidentCategory.allCases) { ctx in
                            Text(ctx.rawValue).tag(ctx)
                        }
                    }
                }

                Section("Details") {
                    TextField("Reported By", text: $reportedBy)
                    TextField("Confidentiality Notice", text: $confidentialityNotice)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 420, height: 340)
        .onAppear {
            selectedContext = incident.context
            // Apply defaults
            if !defaultReportedBy.isEmpty && reportedBy.isEmpty {
                reportedBy = defaultReportedBy
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
        result = result.replacingOccurrences(of: "{type}", with: incident.context.rawValue)
        result = result.replacingOccurrences(of: "{date}", with: Date.now.shortFormatted)
        result = result.replacingOccurrences(of: "{case}", with: incident.title)
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
            reportedBy: reportedBy
        )
        report.confidentialityNotice = confidentialityNotice
        if !defaultBatesPrefix.isEmpty {
            report.batesPrefix = defaultBatesPrefix
        }
        report.incident = incident
        incident.reports.append(report)
        incident.modifiedAt = .now
        // Increment auto-number counter
        if autoNumberReports {
            autoNumberCounter += 1
        }
        onCreated(report)
        dismiss()
    }
}
