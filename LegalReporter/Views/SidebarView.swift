import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LegalCase.modifiedAt, order: .reverse) private var cases: [LegalCase]
    @Query private var allTags: [Tag]

    @Binding var selectedCase: LegalCase?
    @Binding var selectedReport: Report?
    @Binding var showingNewCase: Bool

    @State private var showingDeleteConfirmation = false
    @State private var caseToDelete: LegalCase?
    @State private var searchText = ""
    @State private var statusFilter: CaseStatus?
    @State private var tagFilter: Tag?
    @State private var showFilters = false

    private var filteredCases: [LegalCase] {
        var result = cases
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

    private var starredCases: [LegalCase] { filteredCases.filter { $0.isStarred } }
    private var activeCases: [LegalCase] {
        filteredCases.filter { !$0.isStarred && $0.status != .archived && $0.status != .closed }
    }
    private var closedCases: [LegalCase] {
        filteredCases.filter { !$0.isStarred && ($0.status == .archived || $0.status == .closed) }
    }

    var body: some View {
        List {
            // Dashboard button
            Button {
                selectedCase = nil
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
                TextField("Search cases...", text: $searchText)
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
                        ForEach(CaseStatus.allCases) { status in
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
                    // Show all - reset filters
                } label: {
                    Label {
                        HStack {
                            Text("All Cases")
                            Spacer()
                            Text("\(cases.count)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    } icon: {
                        Image(systemName: "tray.full")
                    }
                }
                .buttonStyle(.plain)

                let overdueCount = cases.flatMap(\.overdueDeadlines).count
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

                let reviewCount = cases.filter { $0.status == .underReview }.count
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
            if !starredCases.isEmpty {
                Section("Starred") {
                    ForEach(starredCases) { legalCase in
                        caseRow(legalCase)
                    }
                }
            }

            // Active Cases
            Section("Cases") {
                ForEach(activeCases) { legalCase in
                    caseRow(legalCase)
                }
            }

            // Closed/Archived
            if !closedCases.isEmpty {
                Section("Closed") {
                    ForEach(closedCases) { legalCase in
                        caseRow(legalCase)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    showingNewCase = true
                } label: {
                    Label("New Case", systemImage: "plus.circle")
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
        .alert("Delete Case?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let caseToDelete {
                    if selectedCase == caseToDelete {
                        selectedCase = nil
                        selectedReport = nil
                    }
                    modelContext.delete(caseToDelete)
                }
            }
        } message: {
            Text("This will permanently delete the case and all its reports.")
        }
    }

    // MARK: - Case Row

    @ViewBuilder
    private func caseRow(_ legalCase: LegalCase) -> some View {
        DisclosureGroup {
            ForEach(legalCase.reports.sorted(by: { $0.modifiedAt > $1.modifiedAt })) { report in
                Button {
                    selectedCase = legalCase
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
                    Button("Duplicate") { duplicateReport(report, in: legalCase) }
                    Divider()
                    Button("Delete", role: .destructive) { deleteReport(report, from: legalCase) }
                }
            }

            Button {
                selectedCase = legalCase
                addReport(to: legalCase)
            } label: {
                Label("New Report", systemImage: "plus")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        } label: {
            Button {
                selectedCase = legalCase
                selectedReport = nil
            } label: {
                HStack(spacing: 6) {
                    // Status dot
                    Circle()
                        .fill(legalCase.status.color)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(legalCase.title.isEmpty ? "Untitled" : legalCase.title)
                                .font(.body)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            if legalCase.isStarred {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }

                            if legalCase.priority == .high || legalCase.priority == .urgent {
                                Image(systemName: legalCase.priority.icon)
                                    .font(.caption2)
                                    .foregroundStyle(legalCase.priority.color)
                            }
                        }

                        HStack(spacing: 6) {
                            Text(legalCase.context.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.blue.opacity(0.1))
                                .clipShape(Capsule())

                            if !legalCase.referenceNumber.isEmpty {
                                Text(legalCase.referenceNumber)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if let deadline = legalCase.nextDeadline {
                                HStack(spacing: 2) {
                                    Image(systemName: deadline.urgencyIcon)
                                        .font(.system(size: 8))
                                    Text(deadline.dueDate.shortLegal)
                                        .font(.system(size: 9))
                                }
                                .foregroundStyle(deadline.urgencyColor)
                            }
                        }

                        // Tags row
                        if !legalCase.tags.isEmpty {
                            HStack(spacing: 3) {
                                ForEach(legalCase.tags.prefix(3)) { tag in
                                    TagPill(tag: tag, size: .small)
                                }
                                if legalCase.tags.count > 3 {
                                    Text("+\(legalCase.tags.count - 3)")
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
                Button("New Report") { addReport(to: legalCase) }
                Divider()

                Button(legalCase.isStarred ? "Unstar" : "Star") {
                    legalCase.isStarred.toggle()
                    legalCase.modifiedAt = .now
                }

                Menu("Status") {
                    ForEach(CaseStatus.allCases) { status in
                        Button {
                            let old = legalCase.status
                            legalCase.status = status
                            legalCase.modifiedAt = .now
                            legalCase.addLogEntry("Status: \(old.rawValue) \u{2192} \(status.rawValue)", type: .statusChange)
                        } label: {
                            Label(status.rawValue, systemImage: status.icon)
                        }
                    }
                }

                Menu("Priority") {
                    ForEach(CasePriority.allCases) { p in
                        Button {
                            legalCase.priority = p
                            legalCase.modifiedAt = .now
                        } label: {
                            Label(p.rawValue, systemImage: p.icon)
                        }
                    }
                }

                Divider()
                Button("Delete Case", role: .destructive) {
                    caseToDelete = legalCase
                    showingDeleteConfirmation = true
                }
            }
        }
    }

    // MARK: - Actions

    private func addReport(to legalCase: LegalCase) {
        let report = Report(title: "", context: legalCase.context)
        report.legalCase = legalCase
        legalCase.reports.append(report)
        legalCase.modifiedAt = .now
        selectedReport = report
    }

    private func duplicateReport(_ report: Report, in legalCase: LegalCase) {
        let copy = Report(title: "\(report.title) (Copy)", context: report.context, preparedBy: report.preparedBy)
        copy.includeHeader = report.includeHeader
        copy.includePageNumbers = report.includePageNumbers
        copy.includeDate = report.includeDate
        copy.sections = report.sortedSections.map { orig in
            let sec = ReportSection(order: orig.order, sectionType: orig.sectionType, content: orig.content)
            sec.exhibitLabel = orig.exhibitLabel
            return sec
        }
        copy.legalCase = legalCase
        legalCase.reports.append(copy)
        legalCase.modifiedAt = .now
        selectedReport = copy
    }

    private func deleteReport(_ report: Report, from legalCase: LegalCase) {
        if selectedReport == report { selectedReport = nil }
        legalCase.reports.removeAll { $0.id == report.id }
        modelContext.delete(report)
        legalCase.modifiedAt = .now
    }
}
