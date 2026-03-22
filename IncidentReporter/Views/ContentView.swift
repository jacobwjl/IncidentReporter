import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Incident.modifiedAt, order: .reverse) private var incidents: [Incident]

    @State private var selectedIncident: Incident?
    @State private var selectedReport: Report?
    @State private var showingNewIncident = false
    @State private var showInspector = false
    @State private var showCommandPalette = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedIncident: $selectedIncident,
                selectedReport: $selectedReport,
                showingNewIncident: $showingNewIncident
            )
            .navigationSplitViewColumnWidth(min: 190, ideal: 240, max: 300)
        } detail: {
            detailView
                .frame(minWidth: 380, maxWidth: .infinity, minHeight: 340, maxHeight: .infinity)
                .clipped()
                .inspector(isPresented: $showInspector) {
                    if let report = selectedReport {
                        ReportInspectorView(report: report, incident: selectedIncident)
                            .inspectorColumnWidth(min: 200, ideal: 240, max: 320)
                    } else if let incident = selectedIncident {
                        IncidentInspectorView(incident: incident)
                            .inspectorColumnWidth(min: 200, ideal: 240, max: 320)
                    }
                }
        }
        .frame(minWidth: 620, minHeight: 440)
        .sheet(isPresented: $showingNewIncident) {
            IncidentEditorView(incident: nil) { newIncident in
                modelContext.insert(newIncident)
                selectedIncident = newIncident
            }
        }
        .overlay {
            if showCommandPalette {
                CommandPaletteOverlay(
                    isPresented: $showCommandPalette,
                    incidents: incidents,
                    onSelectIncident: { incident in
                        selectedIncident = incident
                        selectedReport = nil
                    },
                    onSelectReport: { report, incident in
                        selectedIncident = incident
                        selectedReport = report
                    }
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let report = selectedReport {
                    Button { emailReport(report) } label: {
                        Label("Email", systemImage: "envelope")
                    }
                    .keyboardShortcut("m", modifiers: [.command, .shift])

                    Button("Print") {
                        PrintService.print(report: report, incident: selectedIncident)
                    }
                    .keyboardShortcut("p", modifiers: .command)

                    Button("Export PDF") {
                        PrintService.exportPDF(report: report, incident: selectedIncident)
                    }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                }

                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
        }
        .background {
            Button { showCommandPalette = true } label: { EmptyView() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let report = selectedReport {
            ReportEditorView(report: report, incident: selectedIncident)
        } else if let incident = selectedIncident {
            IncidentDetailView(incident: incident, selectedReport: $selectedReport)
        } else {
            DashboardView()
        }
    }

    private func emailReport(_ report: Report) {
        let subject = report.title.isEmpty ? "Report" : report.title
        let body = report.plainTextExport
        let service = NSSharingService(named: .composeEmail)
        service?.subject = subject
        service?.perform(withItems: [body as NSString])
        if service == nil {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(body, forType: .string)
            let alert = NSAlert()
            alert.messageText = "No Email Client"
            alert.informativeText = "No email app is configured. The report text has been copied to your clipboard."
            alert.runModal()
        }
    }
}

// MARK: - Report Inspector

struct ReportInspectorView: View {
    @Bindable var report: Report
    let incident: Incident?

    var body: some View {
        Form {
            Section("Report Info") {
                LabeledContent("Type", value: report.context.rawValue)
                LabeledContent("Created", value: report.createdAt.shortFormatted)
                LabeledContent("Modified", value: report.modifiedAt.shortFormatted)
                LabeledContent("Words", value: "\(report.wordCount)")
                LabeledContent("Sections", value: "\(report.sections.count)")
                if report.attachmentCount > 0 {
                    LabeledContent("Attachments", value: "\(report.attachmentCount)")
                }
            }

            Section("Options") {
                Toggle("Header Info", isOn: $report.includeHeader)
                Toggle("Page Numbers", isOn: $report.includePageNumbers)
                Toggle("Date", isOn: $report.includeDate)
                Toggle("Bates Numbers", isOn: $report.includeBatesNumbers)
                TextField("Reported By", text: $report.reportedBy)
                TextField("Confidentiality", text: $report.confidentialityNotice)
            }

            if let incident {
                Section("Incident") {
                    LabeledContent("Title", value: incident.displayTitle)
                    HStack(spacing: 6) {
                        Image(systemName: incident.status.icon)
                            .foregroundStyle(incident.status.color)
                        Text(incident.status.rawValue)
                    }
                    if let deadline = incident.nextDeadline {
                        HStack(spacing: 6) {
                            Image(systemName: deadline.urgencyIcon)
                                .foregroundStyle(deadline.urgencyColor)
                            Text(deadline.title)
                            Spacer()
                            Text(deadline.dueDate.shortFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Incident Inspector

struct IncidentInspectorView: View {
    @Bindable var incident: Incident

    var body: some View {
        Form {
            Section("Status") {
                Picker("Status", selection: Binding(
                    get: { incident.status },
                    set: { newVal in
                        let old = incident.status
                        incident.status = newVal
                        incident.modifiedAt = .now
                        incident.addLogEntry("Status changed from \(old.rawValue) to \(newVal.rawValue)", type: .statusChange)
                    }
                )) {
                    ForEach(IncidentStatus.allCases) { status in
                        Label(status.rawValue, systemImage: status.icon).tag(status)
                    }
                }

                Picker("Severity", selection: Binding(
                    get: { incident.priority },
                    set: { incident.priority = $0; incident.modifiedAt = .now }
                )) {
                    ForEach(Severity.allCases) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
            }

            Section("Info") {
                LabeledContent("Category", value: incident.context.rawValue)
                LabeledContent("Created", value: incident.createdAt.shortFormatted)
                LabeledContent("Modified", value: incident.modifiedAt.shortFormatted)
                LabeledContent("Reports", value: "\(incident.reports.count)")
                LabeledContent("Files", value: "\(incident.files.count)")
                if !incident.location.isEmpty {
                    LabeledContent("Location", value: incident.location)
                }
            }

            if !incident.tags.isEmpty {
                Section("Tags") {
                    FlowLayout(spacing: 4) {
                        ForEach(incident.tags) { tag in
                            TagPill(tag: tag)
                        }
                    }
                }
            }

            if !incident.sortedDeadlines.isEmpty {
                Section("Deadlines") {
                    ForEach(incident.sortedDeadlines, id: \.persistentModelID) { deadline in
                        HStack(spacing: 6) {
                            Image(systemName: deadline.urgencyIcon)
                                .foregroundStyle(deadline.urgencyColor)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(deadline.title)
                                    .font(.caption)
                                Text(deadline.dueDate.shortFormatted)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !incident.contacts.isEmpty {
                Section("Contacts") {
                    ForEach(incident.contacts) { contact in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(contact.name)
                                .font(.caption)
                            if !contact.role.isEmpty {
                                Text(contact.role)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tag Pill

struct TagPill: View {
    let tag: Tag
    var size: TagPillSize = .regular
    var onRemove: (() -> Void)? = nil

    enum TagPillSize {
        case small, regular
        var font: Font {
            switch self {
            case .small: return .system(size: 9, weight: .medium)
            case .regular: return .system(size: 11, weight: .medium)
            }
        }
        var hPad: CGFloat { self == .small ? 5 : 8 }
        var vPad: CGFloat { self == .small ? 2 : 3 }
        var dotSize: CGFloat { self == .small ? 5 : 6 }
    }

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(tag.color)
                .frame(width: size.dotSize, height: size.dotSize)
            Text(tag.name)
                .font(size.font)
                .foregroundStyle(.primary)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, size.hPad)
        .padding(.vertical, size.vPad)
        .background(tag.color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let pos = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Command Palette

struct CommandPaletteOverlay: View {
    @Binding var isPresented: Bool
    let incidents: [Incident]
    let onSelectIncident: (Incident) -> Void
    let onSelectReport: (Report, Incident) -> Void

    @State private var query = ""
    @FocusState private var isFocused: Bool

    private var results: [(String, String, () -> Void)] {
        guard !query.isEmpty else {
            return incidents.prefix(8).map { incident in
                (incident.displayTitle, incident.context.rawValue, { onSelectIncident(incident); isPresented = false })
            }
        }
        let q = query.lowercased()
        var items: [(String, String, () -> Void)] = []
        for incident in incidents {
            if incident.title.lowercased().contains(q) || incident.referenceNumber.lowercased().contains(q) {
                items.append((incident.displayTitle, "Incident - \(incident.context.rawValue)", { onSelectIncident(incident); isPresented = false }))
            }
            for r in incident.reports {
                if r.title.lowercased().contains(q) {
                    items.append((r.title.isEmpty ? "Untitled Report" : r.title, "Report in \(incident.title)", { onSelectReport(r, incident); isPresented = false }))
                }
            }
        }
        return Array(items.prefix(12))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search incidents, reports...", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .focused($isFocused)
                        .onSubmit {
                            if let first = results.first { first.2() }
                        }
                }
                .padding(12)

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if query.isEmpty {
                            Text("Recent Incidents")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                        }
                        ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                            Button {
                                result.2()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.0)
                                            .font(.body)
                                        Text(result.1)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
            .frame(width: 520)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .padding(.top, 80)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear { isFocused = true }
        .onExitCommand { isPresented = false }
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isPresented)
    }
}
