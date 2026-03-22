import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Incident.modifiedAt, order: .reverse) private var incidents: [Incident]
    @Query private var allTags: [Tag]

    @Binding var selectedIncident: Incident?
    @Binding var selectedReport: Report?
    @Binding var showingNewIncident: Bool

    @State private var showingDeleteConfirmation = false
    @State private var incidentToDelete: Incident?
    @State private var searchText = ""
    @State private var statusFilter: IncidentStatus?
    @State private var tagFilter: Tag?
    @State private var showFilters = false

    private var filteredIncidents: [Incident] {
        var result = incidents
        if let statusFilter {
            result = result.filter { $0.status == statusFilter }
        }
        if let tagFilter {
            result = result.filter { $0.tags.contains(where: { $0.id == tagFilter.id }) }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                $0.referenceNumber.lowercased().contains(q) ||
                $0.notes.lowercased().contains(q)
            }
        }
        return result
    }

    private var starredIncidents: [Incident] { filteredIncidents.filter { $0.isStarred } }
    private var activeIncidents: [Incident] {
        filteredIncidents.filter { !$0.isStarred && $0.status != .archived && $0.status != .closed }
    }
    private var closedIncidents: [Incident] {
        filteredIncidents.filter { !$0.isStarred && ($0.status == .archived || $0.status == .closed) }
    }

    var body: some View {
        List {
            // Dashboard button
            Button {
                selectedIncident = nil
                selectedReport = nil
            } label: {
                Label("Dashboard", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search incidents...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Filters
            if showFilters {
                VStack(alignment: .leading, spacing: 6) {
                    // Status filter
                    HStack(spacing: 4) {
                        ForEach(IncidentStatus.allCases) { status in
                            Button {
                                statusFilter = statusFilter == status ? nil : status
                            } label: {
                                Image(systemName: status.icon)
                                    .font(.caption2)
                                    .foregroundStyle(statusFilter == status ? .white : status.color)
                                    .frame(width: 20, height: 20)
                                    .background(statusFilter == status ? status.color : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .help(status.rawValue)
                        }
                        Spacer()
                        if statusFilter != nil || tagFilter != nil {
                            Button("Clear") {
                                statusFilter = nil
                                tagFilter = nil
                            }
                            .font(.caption2)
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                        }
                    }

                    // Tag filter
                    if !allTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(allTags) { tag in
                                    Button {
                                        tagFilter = tagFilter?.id == tag.id ? nil : tag
                                    } label: {
                                        TagPill(tag: tag, size: .small)
                                            .opacity(tagFilter == nil || tagFilter?.id == tag.id ? 1 : 0.4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Smart Folders
            Section("Smart Folders") {
                Button {
                    statusFilter = nil
                    tagFilter = nil
                    searchText = ""
                } label: {
                    Label {
                        HStack {
                            Text("All Incidents")
                            Spacer()
                            Text("\(incidents.count)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    } icon: {
                        Image(systemName: "tray.full")
                    }
                }
                .buttonStyle(.plain)

                let overdueCount = incidents.flatMap(\.overdueDeadlines).count
                if overdueCount > 0 {
                    Button {
                        // Could implement a special filter here
                    } label: {
                        Label {
                            HStack {
                                Text("Overdue")
                                Spacer()
                                Text("\(overdueCount)")
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.red.opacity(0.15))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.red)
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.clock")
                                .foregroundStyle(.red)
                        }
                    }
                    .buttonStyle(.plain)
                }

                let reviewCount = incidents.filter { $0.status == .underReview }.count
                if reviewCount > 0 {
                    Button {
                        statusFilter = .underReview
                    } label: {
                        Label {
                            HStack {
                                Text("Needs Review")
                                Spacer()
                                Text("\(reviewCount)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        } icon: {
                            Image(systemName: "eye")
                                .foregroundStyle(.orange)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Starred
            if !starredIncidents.isEmpty {
                Section("Starred") {
                    ForEach(starredIncidents) { incident in
                        incidentRow(incident)
                    }
                }
            }

            // Active Incidents
            Section("Incidents") {
                ForEach(activeIncidents) { incident in
                    incidentRow(incident)
                }
            }

            // Closed/Archived
            if !closedIncidents.isEmpty {
                Section("Closed") {
                    ForEach(closedIncidents) { incident in
                        incidentRow(incident)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    showingNewIncident = true
                } label: {
                    Label("New Incident", systemImage: "plus.circle")
                }
                .buttonStyle(.plain)
                .padding()

                Spacer()

                Button {
                    withAnimation { showFilters.toggle() }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(showFilters || statusFilter != nil || tagFilter != nil ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .padding()
                .help("Toggle Filters")
            }
        }
        .alert("Delete Incident?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let incidentToDelete {
                    if selectedIncident == incidentToDelete {
                        selectedIncident = nil
                        selectedReport = nil
                    }
                    modelContext.delete(incidentToDelete)
                }
            }
        } message: {
            Text("This will permanently delete the incident and all its reports.")
        }
    }

    // MARK: - Incident Row

    @ViewBuilder
    private func incidentRow(_ incident: Incident) -> some View {
        DisclosureGroup {
            ForEach(incident.reports.sorted(by: { $0.modifiedAt > $1.modifiedAt })) { report in
                Button {
                    selectedIncident = incident
                    selectedReport = report
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.title.isEmpty ? "Untitled Report" : report.title)
                                .font(.body)
                                .lineLimit(1)
                            Text(report.context.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "doc.text")
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
                .contextMenu {
                    Button("Duplicate") { duplicateReport(report, in: incident) }
                    Divider()
                    Button("Delete", role: .destructive) { deleteReport(report, from: incident) }
                }
            }

            Button {
                selectedIncident = incident
                addReport(to: incident)
            } label: {
                Label("New Report", systemImage: "plus")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        } label: {
            Button {
                selectedIncident = incident
                selectedReport = nil
            } label: {
                HStack(spacing: 6) {
                    // Status dot
                    Circle()
                        .fill(incident.status.color)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(incident.title.isEmpty ? "Untitled" : incident.title)
                                .font(.body)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            if incident.isStarred {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }

                            if incident.priority == .high || incident.priority == .critical {
                                Image(systemName: incident.priority.icon)
                                    .font(.caption2)
                                    .foregroundStyle(incident.priority.color)
                            }
                        }

                        HStack(spacing: 6) {
                            Text(incident.context.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.blue.opacity(0.1))
                                .clipShape(Capsule())

                            if !incident.referenceNumber.isEmpty {
                                Text(incident.referenceNumber)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if let deadline = incident.nextDeadline {
                                HStack(spacing: 2) {
                                    Image(systemName: deadline.urgencyIcon)
                                        .font(.system(size: 8))
                                    Text(deadline.dueDate.shortFormatted)
                                        .font(.system(size: 9))
                                }
                                .foregroundStyle(deadline.urgencyColor)
                            }
                        }

                        // Location subtitle
                        if !incident.location.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                Text(incident.location)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        // Tags row
                        if !incident.tags.isEmpty {
                            HStack(spacing: 3) {
                                ForEach(incident.tags.prefix(3)) { tag in
                                    TagPill(tag: tag, size: .small)
                                }
                                if incident.tags.count > 3 {
                                    Text("+\(incident.tags.count - 3)")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("New Report") { addReport(to: incident) }
                Divider()

                Button(incident.isStarred ? "Unstar" : "Star") {
                    incident.isStarred.toggle()
                    incident.modifiedAt = .now
                }

                Menu("Status") {
                    ForEach(IncidentStatus.allCases) { status in
                        Button {
                            let old = incident.status
                            incident.status = status
                            incident.modifiedAt = .now
                            incident.addLogEntry("Status: \(old.rawValue) \u{2192} \(status.rawValue)", type: .statusChange)
                        } label: {
                            Label(status.rawValue, systemImage: status.icon)
                        }
                    }
                }

                Menu("Severity") {
                    ForEach(Severity.allCases) { s in
                        Button {
                            incident.priority = s
                            incident.modifiedAt = .now
                        } label: {
                            Label(s.rawValue, systemImage: s.icon)
                        }
                    }
                }

                Divider()
                Button("Delete Incident", role: .destructive) {
                    incidentToDelete = incident
                    showingDeleteConfirmation = true
                }
            }
        }
    }

    // MARK: - Actions

    private func addReport(to incident: Incident) {
        let report = Report(title: "", context: incident.context)
        report.incident = incident
        incident.reports.append(report)
        incident.modifiedAt = .now
        selectedReport = report
    }

    private func duplicateReport(_ report: Report, in incident: Incident) {
        let copy = Report(title: "\(report.title) (Copy)", context: report.context, reportedBy: report.reportedBy)
        copy.includeHeader = report.includeHeader
        copy.includePageNumbers = report.includePageNumbers
        copy.includeDate = report.includeDate
        copy.sections = report.sortedSections.map { orig in
            let sec = ReportSection(order: orig.order, sectionType: orig.sectionType, content: orig.content)
            sec.exhibitLabel = orig.exhibitLabel
            return sec
        }
        copy.incident = incident
        incident.reports.append(copy)
        incident.modifiedAt = .now
        selectedReport = copy
    }

    private func deleteReport(_ report: Report, from incident: Incident) {
        if selectedReport == report { selectedReport = nil }
        incident.reports.removeAll { $0.id == report.id }
        modelContext.delete(report)
        incident.modifiedAt = .now
    }
}
