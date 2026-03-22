import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var incidents: [Incident]
    @Query private var reports: [Report]
    @Query private var attachments: [FileAttachment]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(.system(size: 24, weight: .bold))
                        Text(Date.now.dateFormatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Big numbers
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    StatCard(value: "\(incidents.count)", label: "Incidents", icon: "exclamationmark.triangle.fill", color: .red)
                    StatCard(value: "\(reports.count)", label: "Reports", icon: "doc.text.fill", color: .green)
                    StatCard(value: "\(totalWords)", label: "Words Written", icon: "text.word.spacing", color: .orange)
                    StatCard(value: "\(attachments.count)", label: "Files Attached", icon: "paperclip", color: .purple)
                }

                // Status Distribution
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Status Distribution")
                            .font(.system(size: 14, weight: .semibold))

                        let maxStatusCount = IncidentStatus.allCases.map { s in
                            incidents.filter { $0.status == s }.count
                        }.max() ?? 1

                        ForEach(IncidentStatus.allCases) { status in
                            let count = incidents.filter { $0.status == status }.count
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(status.color)
                                    .frame(width: 8, height: 8)
                                Text(status.rawValue)
                                    .font(.body)
                                    .frame(width: 100, alignment: .leading)
                                Text("\(count)")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, alignment: .trailing)

                                GeometryReader { geo in
                                    let pct = maxStatusCount > 0 ? CGFloat(count) / CGFloat(maxStatusCount) : 0
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(status.color.opacity(0.35))
                                        .frame(width: geo.size.width * pct)
                                }
                                .frame(height: 14)
                            }
                        }
                    }
                    .padding(4)
                }

                // Upcoming Deadlines
                if !upcomingDeadlines.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Upcoming Deadlines")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text("\(upcomingDeadlines.count) shown")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            ForEach(Array(upcomingDeadlines.enumerated()), id: \.offset) { index, item in
                                let deadline = item.0
                                let incidentName = item.1
                                HStack(spacing: 8) {
                                    Image(systemName: deadline.urgencyIcon)
                                        .font(.caption)
                                        .foregroundStyle(deadline.urgencyColor)
                                        .frame(width: 16)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(deadline.title.isEmpty ? "Untitled Deadline" : deadline.title)
                                            .font(.body)
                                            .foregroundStyle(deadline.isOverdue ? .red : .primary)
                                        Text(incidentName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text(deadline.dueDate.shortFormatted)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundStyle(deadline.isOverdue ? .red : .secondary)
                                        if deadline.isOverdue {
                                            Text("OVERDUE")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.red)
                                        } else {
                                            Text(deadline.dueDate.relativeFormatted)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)

                                if index < upcomingDeadlines.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(4)
                    }
                }

                // Recent Activity Feed
                if !recentActivityEntries.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Recent Activity")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text("Last \(recentActivityEntries.count) entries")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            ForEach(Array(recentActivityEntries.enumerated()), id: \.offset) { index, item in
                                let entry = item.0
                                let incidentName = item.1
                                HStack(spacing: 8) {
                                    Image(systemName: entry.entryType.icon)
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        .frame(width: 16)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.message)
                                            .font(.body)
                                            .lineLimit(2)
                                        HStack(spacing: 6) {
                                            Text(incidentName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text("\u{2022}")
                                                .font(.caption2)
                                                .foregroundStyle(.quaternary)
                                            Text(entry.timestamp.relativeFormatted)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 2)

                                if index < recentActivityEntries.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(4)
                    }
                }

                // Categories breakdown
                if !contextBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("By Category")
                            .font(.system(size: 14, weight: .semibold))

                        ForEach(contextBreakdown, id: \.0) { ctx, count in
                            HStack {
                                Text(ctx)
                                    .font(.body)
                                Spacer()
                                Text("\(count)")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                // Mini bar
                                GeometryReader { geo in
                                    let maxCount = contextBreakdown.map(\.1).max() ?? 1
                                    let pct = CGFloat(count) / CGFloat(maxCount)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill((IncidentCategory(rawValue: ctx)?.theme.accentColor ?? .red).opacity(0.2))
                                        .frame(width: geo.size.width * pct)
                                }
                                .frame(width: 100, height: 14)
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Recently Modified reports
                if !recentReports.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recently Modified")
                            .font(.system(size: 14, weight: .semibold))

                        ForEach(recentReports) { report in
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(report.title.isEmpty ? "Untitled" : report.title)
                                        .font(.body)
                                    Text(report.context.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(report.modifiedAt.shortFormatted)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Fun stats
                VStack(alignment: .leading, spacing: 10) {
                    Text("Fun Facts")
                        .font(.system(size: 14, weight: .semibold))

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 10) {
                        FunFactCard(icon: "book.pages", title: "Pages (est.)", value: "\(estimatedPages)")
                        FunFactCard(icon: "clock", title: "Avg Words/Report", value: reports.isEmpty ? "\u{2014}" : "\(totalWords / max(reports.count, 1))")
                        FunFactCard(icon: "calendar", title: "First Incident", value: oldestIncidentDate)
                        FunFactCard(icon: "flame", title: "Most Sections", value: "\(maxSections) sections")
                        FunFactCard(icon: "arrow.up.right", title: "Longest Report", value: "\(longestReportWords) words")
                        FunFactCard(icon: "photo.stack", title: "Total File Size", value: totalFileSize)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(20)
            .frame(maxWidth: 760)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed Stats

    private var totalWords: Int {
        reports.reduce(0) { $0 + $1.wordCount }
    }

    private var estimatedPages: Int {
        max(1, totalWords / 250) // ~250 words per page
    }

    private var contextBreakdown: [(String, Int)] {
        var counts: [String: Int] = [:]
        for incident in incidents {
            counts[incident.context.rawValue, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }
    }

    private var maxSections: Int {
        reports.map { $0.sections.count }.max() ?? 0
    }

    private var longestReportWords: Int {
        reports.map { $0.wordCount }.max() ?? 0
    }

    private var oldestIncidentDate: String {
        guard let oldest = incidents.min(by: { $0.createdAt < $1.createdAt }) else { return "\u{2014}" }
        return oldest.createdAt.shortFormatted
    }

    private var totalFileSize: String {
        let bytes = Double(attachments.reduce(0) { $0 + $1.fileSizeBytes })
        if bytes < 1024 { return "\(Int(bytes)) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", bytes / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", bytes / (1024 * 1024)) }
        return String(format: "%.2f GB", bytes / (1024 * 1024 * 1024))
    }

    private var recentReports: [Report] {
        Array(reports.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(5))
    }

    private var upcomingDeadlines: [(Deadline, String)] {
        var all: [(Deadline, String)] = []
        for incident in incidents {
            for d in incident.deadlines where !d.isCompleted {
                all.append((d, incident.title.isEmpty ? "Untitled" : incident.title))
            }
        }
        // Overdue first (sorted by date ascending), then upcoming by date ascending
        let overdue = all.filter { $0.0.isOverdue }.sorted { $0.0.dueDate < $1.0.dueDate }
        let upcoming = all.filter { !$0.0.isOverdue }.sorted { $0.0.dueDate < $1.0.dueDate }
        return Array((overdue + upcoming).prefix(5))
    }

    private var recentActivityEntries: [(ActivityLogEntry, String)] {
        var all: [(ActivityLogEntry, String)] = []
        for incident in incidents {
            for entry in incident.activityLog {
                all.append((entry, incident.title.isEmpty ? "Untitled" : incident.title))
            }
        }
        return Array(all.sorted { $0.0.timestamp > $1.0.timestamp }.prefix(10))
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Fun Fact Card

struct FunFactCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .medium))
            }
            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
