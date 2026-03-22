import SwiftData
import Foundation

// MARK: - Incident Category

enum IncidentCategory: String, CaseIterable, Identifiable, Codable {
    case safety = "Safety"
    case security = "Security"
    case maintenance = "Maintenance"
    case environmental = "Environmental"
    case health = "Health"
    case workplace = "Workplace"
    case vehicle = "Vehicle"
    case property = "Property"
    case general = "General"
    case other = "Other"

    var id: String { rawValue }

    var defaultFieldLabels: [(String, String)] {
        switch self {
        case .safety:
            return [("Location", ""), ("Date/Time", ""), ("Reported By", ""), ("Injuries", "")]
        case .security:
            return [("Location", ""), ("Date/Time", ""), ("Reported By", ""), ("Suspect Description", "")]
        case .maintenance:
            return [("Location", ""), ("Equipment/Asset", ""), ("Reported By", ""), ("Date Discovered", "")]
        case .environmental:
            return [("Location", ""), ("Date/Time", ""), ("Substance/Material", ""), ("Reported By", "")]
        case .health:
            return [("Location", ""), ("Date/Time", ""), ("Person Affected", ""), ("Reported By", "")]
        case .workplace:
            return [("Department", ""), ("Employee", ""), ("Supervisor", ""), ("Date of Incident", "")]
        case .vehicle:
            return [("Vehicle Info", ""), ("Location", ""), ("Date/Time", ""), ("Driver", "")]
        case .property:
            return [("Property Address", ""), ("Date/Time", ""), ("Reported By", ""), ("Damage Description", "")]
        case .general:
            return [("Reference #", ""), ("Date", "")]
        case .other:
            return []
        }
    }

    var defaultSections: [ReportSection] {
        switch self {
        case .safety:
            return [
                ReportSection(order: 0, sectionType: .heading, content: "INCIDENT SUMMARY"),
                ReportSection(order: 1, sectionType: .text, content: ""),
                ReportSection(order: 2, sectionType: .heading, content: "DESCRIPTION OF EVENTS"),
                ReportSection(order: 3, sectionType: .text, content: ""),
                ReportSection(order: 4, sectionType: .heading, content: "INJURIES/DAMAGES"),
                ReportSection(order: 5, sectionType: .text, content: ""),
                ReportSection(order: 6, sectionType: .heading, content: "CORRECTIVE ACTIONS"),
                ReportSection(order: 7, sectionType: .text, content: ""),
            ]
        case .security:
            return [
                ReportSection(order: 0, sectionType: .heading, content: "INCIDENT SUMMARY"),
                ReportSection(order: 1, sectionType: .text, content: ""),
                ReportSection(order: 2, sectionType: .heading, content: "DETAILS"),
                ReportSection(order: 3, sectionType: .text, content: ""),
                ReportSection(order: 4, sectionType: .heading, content: "RESPONSE ACTIONS"),
                ReportSection(order: 5, sectionType: .text, content: ""),
            ]
        case .maintenance:
            return [
                ReportSection(order: 0, sectionType: .heading, content: "ISSUE DESCRIPTION"),
                ReportSection(order: 1, sectionType: .text, content: ""),
                ReportSection(order: 2, sectionType: .heading, content: "ROOT CAUSE"),
                ReportSection(order: 3, sectionType: .text, content: ""),
                ReportSection(order: 4, sectionType: .heading, content: "REPAIR ACTIONS"),
                ReportSection(order: 5, sectionType: .text, content: ""),
            ]
        case .environmental:
            return [
                ReportSection(order: 0, sectionType: .heading, content: "SUMMARY"),
                ReportSection(order: 1, sectionType: .text, content: ""),
                ReportSection(order: 2, sectionType: .heading, content: "DETAILS"),
                ReportSection(order: 3, sectionType: .text, content: ""),
                ReportSection(order: 4, sectionType: .heading, content: "ACTIONS"),
                ReportSection(order: 5, sectionType: .text, content: ""),
            ]
        case .health:
            return [
                ReportSection(order: 0, sectionType: .heading, content: "SUMMARY"),
                ReportSection(order: 1, sectionType: .text, content: ""),
                ReportSection(order: 2, sectionType: .heading, content: "DETAILS"),
                ReportSection(order: 3, sectionType: .text, content: ""),
                ReportSection(order: 4, sectionType: .heading, content: "ACTIONS"),
                ReportSection(order: 5, sectionType: .text, content: ""),
            ]
        case .workplace:
            return [
                ReportSection(order: 0, sectionType: .heading, content: "SUMMARY"),
                ReportSection(order: 1, sectionType: .text, content: ""),
                ReportSection(order: 2, sectionType: .heading, content: "DETAILS"),
                ReportSection(order: 3, sectionType: .text, content: ""),
                ReportSection(order: 4, sectionType: .heading, content: "RESOLUTION"),
                ReportSection(order: 5, sectionType: .text, content: ""),
            ]
        case .vehicle:
            return [
                ReportSection(order: 0, sectionType: .heading, content: "SUMMARY"),
                ReportSection(order: 1, sectionType: .text, content: ""),
                ReportSection(order: 2, sectionType: .heading, content: "DETAILS"),
                ReportSection(order: 3, sectionType: .text, content: ""),
                ReportSection(order: 4, sectionType: .heading, content: "ACTIONS"),
                ReportSection(order: 5, sectionType: .text, content: ""),
            ]
        case .property:
            return [
                ReportSection(order: 0, sectionType: .heading, content: "SUMMARY"),
                ReportSection(order: 1, sectionType: .text, content: ""),
                ReportSection(order: 2, sectionType: .heading, content: "DETAILS"),
                ReportSection(order: 3, sectionType: .text, content: ""),
                ReportSection(order: 4, sectionType: .heading, content: "ACTIONS"),
                ReportSection(order: 5, sectionType: .text, content: ""),
            ]
        case .general:
            return [
                ReportSection(order: 0, sectionType: .heading, content: ""),
                ReportSection(order: 1, sectionType: .text, content: ""),
            ]
        case .other:
            return [ReportSection(order: 0, sectionType: .text, content: "")]
        }
    }
}

// MARK: - Incident Status

enum IncidentStatus: String, CaseIterable, Identifiable, Codable {
    case open = "Open"
    case active = "Active"
    case underReview = "Under Review"
    case closed = "Closed"
    case archived = "Archived"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .open: return "circle"
        case .active: return "circle.inset.filled"
        case .underReview: return "eye.circle"
        case .closed: return "checkmark.circle"
        case .archived: return "archivebox"
        }
    }
}

// MARK: - Severity

enum Severity: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .none: return "minus"
        case .low: return "arrow.down"
        case .medium: return "equal"
        case .high: return "arrow.up"
        case .critical: return "exclamationmark.2"
        }
    }
}

// MARK: - Incident Source

enum IncidentSource: String, CaseIterable, Identifiable, Codable {
    case inPerson = "In Person"
    case email = "Email"
    case phone = "Phone"
    case online = "Online"
    case anonymous = "Anonymous"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .inPerson: return "person.fill"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .online: return "globe"
        case .anonymous: return "person.fill.questionmark"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Tag Color Presets

enum TagColor: String, CaseIterable, Identifiable, Codable {
    case red, orange, yellow, green, teal, blue, indigo, purple, pink, gray

    var id: String { rawValue }

    var hex: String {
        switch self {
        case .red: return "#E53E3E"
        case .orange: return "#DD6B20"
        case .yellow: return "#D69E2E"
        case .green: return "#38A169"
        case .teal: return "#319795"
        case .blue: return "#3182CE"
        case .indigo: return "#5A67D8"
        case .purple: return "#805AD5"
        case .pink: return "#D53F8C"
        case .gray: return "#718096"
        }
    }
}

// MARK: - Tag

@Model
final class Tag {
    var name: String
    var colorHex: String
    var createdAt: Date
    var incidents: [Incident]

    init(name: String, colorHex: String = TagColor.blue.hex) {
        self.name = name
        self.colorHex = colorHex
        self.createdAt = .now
        self.incidents = []
    }

    var tagColor: TagColor? {
        TagColor.allCases.first { $0.hex == colorHex }
    }
}

// MARK: - Contact / Party

@Model
final class Contact {
    var name: String
    var role: String
    var email: String
    var phone: String
    var organization: String
    var notes: String
    var createdAt: Date
    var incident: Incident?

    init(name: String = "", role: String = "", email: String = "", phone: String = "", organization: String = "", notes: String = "") {
        self.name = name
        self.role = role
        self.email = email
        self.phone = phone
        self.organization = organization
        self.notes = notes
        self.createdAt = .now
    }
}

// MARK: - Deadline

@Model
final class Deadline {
    var title: String
    var dueDate: Date
    var isCompleted: Bool
    var notes: String
    var createdAt: Date
    var incident: Incident?

    init(title: String = "", dueDate: Date = .now, notes: String = "") {
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = false
        self.notes = notes
        self.createdAt = .now
    }

    var isOverdue: Bool { !isCompleted && dueDate < .now }
    var isDueSoon: Bool { !isCompleted && !isOverdue && dueDate.timeIntervalSinceNow < 3 * 24 * 3600 }
}

// MARK: - Report Template

@Model
final class ReportTemplate {
    var name: String
    var contextTypeRaw: String
    var sectionData: Data
    var createdAt: Date

    init(name: String, context: IncidentCategory, sections: [TemplateSectionData]) {
        self.name = name
        self.contextTypeRaw = context.rawValue
        self.createdAt = .now
        self.sectionData = (try? JSONEncoder().encode(sections)) ?? Data()
    }

    var context: IncidentCategory { IncidentCategory(rawValue: contextTypeRaw) ?? .general }
    var sections: [TemplateSectionData] {
        (try? JSONDecoder().decode([TemplateSectionData].self, from: sectionData)) ?? []
    }
}

struct TemplateSectionData: Codable {
    let order: Int
    let sectionType: String
    let content: String
    let exhibitLabel: String?
}

// MARK: - Activity Log Entry

@Model
final class ActivityLogEntry {
    var message: String
    var timestamp: Date
    var entryTypeRaw: String
    var incident: Incident?

    init(message: String, entryType: ActivityType = .note) {
        self.message = message
        self.timestamp = .now
        self.entryTypeRaw = entryType.rawValue
    }

    var entryType: ActivityType { ActivityType(rawValue: entryTypeRaw) ?? .note }
}

enum ActivityType: String, CaseIterable, Identifiable, Codable {
    case note = "Note"
    case update = "Update"
    case statusChange = "Status Change"
    case milestone = "Milestone"
    case filing = "Filing"
    case communication = "Communication"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .note: return "note.text"
        case .update: return "pencil.circle"
        case .statusChange: return "arrow.triangle.2.circlepath"
        case .milestone: return "flag"
        case .filing: return "doc.badge.plus"
        case .communication: return "bubble.left"
        }
    }
}

// MARK: - Incident

@Model
final class Incident {
    var title: String
    var referenceNumber: String
    var contextTypeRaw: String
    var notes: String
    var createdAt: Date
    var modifiedAt: Date
    var statusRaw: String
    var priorityRaw: String
    var isStarred: Bool
    var location: String
    var sourceRaw: String

    @Relationship(deleteRule: .cascade, inverse: \Report.incident)
    var reports: [Report]

    @Relationship(deleteRule: .cascade, inverse: \FileAttachment.incident)
    var files: [FileAttachment]

    @Relationship(deleteRule: .cascade, inverse: \IncidentField.incident)
    var fields: [IncidentField]

    @Relationship(deleteRule: .cascade, inverse: \Contact.incident)
    var contacts: [Contact]

    @Relationship(deleteRule: .cascade, inverse: \Deadline.incident)
    var deadlines: [Deadline]

    @Relationship(deleteRule: .cascade, inverse: \ActivityLogEntry.incident)
    var activityLog: [ActivityLogEntry]

    @Relationship(inverse: \Tag.incidents)
    var tags: [Tag]

    init(
        title: String = "", referenceNumber: String = "", context: IncidentCategory = .general,
        notes: String = "", status: IncidentStatus = .open, priority: Severity = .none,
        location: String = "", source: IncidentSource = .inPerson
    ) {
        self.title = title
        self.referenceNumber = referenceNumber
        self.contextTypeRaw = context.rawValue
        self.notes = notes
        self.createdAt = .now
        self.modifiedAt = .now
        self.statusRaw = status.rawValue
        self.priorityRaw = priority.rawValue
        self.isStarred = false
        self.location = location
        self.sourceRaw = source.rawValue
        self.reports = []
        self.files = []
        self.tags = []
        self.contacts = []
        self.deadlines = []
        self.activityLog = []
        self.fields = context.defaultFieldLabels.enumerated().map { i, pair in
            IncidentField(label: pair.0, value: pair.1, order: i)
        }
    }

    var context: IncidentCategory {
        get { IncidentCategory(rawValue: contextTypeRaw) ?? .general }
        set { contextTypeRaw = newValue.rawValue }
    }
    var status: IncidentStatus {
        get { IncidentStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
    var priority: Severity {
        get { Severity(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }
    var source: IncidentSource {
        get { IncidentSource(rawValue: sourceRaw) ?? .inPerson }
        set { sourceRaw = newValue.rawValue }
    }

    var displayTitle: String {
        if !referenceNumber.isEmpty && !title.isEmpty { return "\(referenceNumber) \u{2014} \(title)" }
        return title.isEmpty ? "Untitled" : title
    }

    var sortedFields: [IncidentField] { fields.sorted { $0.order < $1.order } }
    var sortedDeadlines: [Deadline] { deadlines.sorted { $0.dueDate < $1.dueDate } }
    var nextDeadline: Deadline? { deadlines.filter { !$0.isCompleted }.sorted { $0.dueDate < $1.dueDate }.first }
    var overdueDeadlines: [Deadline] { deadlines.filter { $0.isOverdue } }
    var sortedActivityLog: [ActivityLogEntry] { activityLog.sorted { $0.timestamp > $1.timestamp } }

    var headerBlock: [(String, String)] {
        var pairs: [(String, String)] = []
        if !referenceNumber.isEmpty { pairs.append(("Ref", referenceNumber)) }
        for field in sortedFields where !field.value.isEmpty { pairs.append((field.label, field.value)) }
        return pairs
    }

    func addLogEntry(_ message: String, type: ActivityType = .note) {
        let entry = ActivityLogEntry(message: message, entryType: type)
        entry.incident = self
        activityLog.append(entry)
    }
}

// MARK: - Incident Field

@Model
final class IncidentField {
    var label: String
    var value: String
    var order: Int
    var incident: Incident?

    init(label: String = "", value: String = "", order: Int = 0) {
        self.label = label
        self.value = value
        self.order = order
    }
}

// MARK: - Report

@Model
final class Report {
    var title: String
    var contextTypeRaw: String
    var createdAt: Date
    var modifiedAt: Date
    var reportedBy: String
    var includeHeader: Bool
    var includePageNumbers: Bool
    var includeDate: Bool
    var includeBatesNumbers: Bool
    var batesPrefix: String
    var batesStartNumber: Int
    var confidentialityNotice: String

    var incident: Incident?

    @Relationship(deleteRule: .cascade, inverse: \ReportSection.report)
    var sections: [ReportSection]

    init(title: String = "", context: IncidentCategory = .general, reportedBy: String = "") {
        self.title = title
        self.contextTypeRaw = context.rawValue
        self.createdAt = .now
        self.modifiedAt = .now
        self.reportedBy = reportedBy
        self.includeHeader = true
        self.includePageNumbers = true
        self.includeDate = true
        self.includeBatesNumbers = false
        self.batesPrefix = ""
        self.batesStartNumber = 1
        self.confidentialityNotice = ""
        self.sections = context.defaultSections
    }

    var context: IncidentCategory { IncidentCategory(rawValue: contextTypeRaw) ?? .general }
    var sortedSections: [ReportSection] { sections.sorted { $0.order < $1.order } }

    var wordCount: Int {
        sections.reduce(0) { total, section in
            total + section.content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        }
    }

    var attachmentCount: Int { sections.reduce(0) { $0 + $1.attachments.count } }

    var plainTextExport: String {
        var output = ""
        if includeDate { output += Date.now.dateFormatted + "\n\n" }
        if !title.isEmpty {
            output += title.uppercased() + "\n"
            output += String(repeating: "\u{2500}", count: title.count) + "\n\n"
        }
        if includeHeader, let incident {
            for (label, value) in incident.headerBlock { output += "\(label): \(value)\n" }
            output += "\n"
        }
        for section in sortedSections {
            switch section.sectionType {
            case .heading:
                output += "\(section.content.uppercased())\n"
                output += String(repeating: "\u{2500}", count: section.content.count) + "\n\n"
            case .text:
                output += section.content + "\n\n"
            case .numberedList:
                let items = section.content.components(separatedBy: "\n").filter { !$0.isEmpty }
                for (i, item) in items.enumerated() { output += "  \(i + 1). \(item)\n" }
                output += "\n"
            case .infoBox:
                output += "\u{250C}" + String(repeating: "\u{2500}", count: 50) + "\u{2510}\n"
                for line in section.content.components(separatedBy: "\n") {
                    output += "\u{2502} \(line.padding(toLength: 49, withPad: " ", startingAt: 0))\u{2502}\n"
                }
                output += "\u{2514}" + String(repeating: "\u{2500}", count: 50) + "\u{2518}\n\n"
            case .fileAttachment:
                let label = section.exhibitLabel ?? "Attachment"
                output += "[\(label)]\n"
                for attachment in section.attachments { output += "  \u{25B8} \(attachment.filename) (\(attachment.formattedSize))\n" }
                if !section.content.isEmpty { output += section.content + "\n" }
                output += "\n"
            case .separator:
                output += String(repeating: "\u{2500}", count: 55) + "\n\n"
            case .signature:
                output += "\n\n____________________________________\n"
                if !section.content.isEmpty { output += section.content + "\n" }
                output += "Date: ____________\n\n"
            case .checklist:
                let items = section.content.components(separatedBy: "\n").filter { !$0.isEmpty }
                for item in items {
                    if item.hasPrefix("[x] ") { output += "  [x] \(String(item.dropFirst(4)))\n" }
                    else if item.hasPrefix("[ ] ") { output += "  [ ] \(String(item.dropFirst(4)))\n" }
                    else { output += "  [ ] \(item)\n" }
                }
                output += "\n"
            case .table:
                let rows = section.content.components(separatedBy: "\n").filter { !$0.isEmpty }
                for row in rows {
                    let cols = row.components(separatedBy: "\t")
                    if cols.count >= 2 { output += "  \(cols[0].padding(toLength: 20, withPad: " ", startingAt: 0))  \(cols[1])\n" }
                    else { output += "  \(row)\n" }
                }
                output += "\n"
            case .blockQuote:
                let quoteLines = section.content.components(separatedBy: "\n")
                let hasAttribution = quoteLines.last?.hasPrefix("-- ") ?? false
                let textLines = hasAttribution ? quoteLines.dropLast() : ArraySlice(quoteLines)
                for line in textLines { output += "  \u{2502} \(line)\n" }
                if hasAttribution, let lastLine = quoteLines.last {
                    output += "  \u{2014} \(String(lastLine.dropFirst(3)))\n"
                }
                output += "\n"
            }
        }
        if !reportedBy.isEmpty { output += "Reported by: \(reportedBy)\n" }
        if !confidentialityNotice.isEmpty { output += "\n\(confidentialityNotice)\n" }
        return output
    }

    func batesNumber(for page: Int) -> String {
        let num = batesStartNumber + page - 1
        let padded = String(format: "%06d", num)
        return batesPrefix.isEmpty ? padded : "\(batesPrefix)-\(padded)"
    }

    var templateSections: [TemplateSectionData] {
        sortedSections.map { s in
            TemplateSectionData(order: s.order, sectionType: s.sectionTypeRaw, content: s.content, exhibitLabel: s.exhibitLabel)
        }
    }

    func applySections(from template: [TemplateSectionData]) {
        sections.removeAll()
        for data in template {
            let section = ReportSection(order: data.order, sectionType: SectionType(rawValue: data.sectionType) ?? .text, content: data.content)
            section.exhibitLabel = data.exhibitLabel
            section.report = self
            sections.append(section)
        }
    }
}

// MARK: - Section Types

enum SectionType: String, CaseIterable, Identifiable, Codable {
    case heading = "Heading"
    case text = "Text"
    case numberedList = "Numbered List"
    case infoBox = "Info Box"
    case fileAttachment = "File / Photo"
    case separator = "Separator"
    case signature = "Signature Block"
    case checklist = "Checklist"
    case table = "Table"
    case blockQuote = "Block Quote"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .heading: return "textformat"
        case .text: return "text.alignleft"
        case .numberedList: return "list.number"
        case .infoBox: return "rectangle.inset.filled"
        case .fileAttachment: return "photo"
        case .separator: return "minus"
        case .signature: return "signature"
        case .checklist: return "checklist"
        case .table: return "tablecells"
        case .blockQuote: return "text.quote"
        }
    }
}

// MARK: - Report Section

@Model
final class ReportSection {
    var order: Int
    var sectionTypeRaw: String
    var content: String
    var addedAt: Date
    var lastEditedAt: Date
    var exhibitLabel: String?
    var report: Report?

    @Relationship(deleteRule: .cascade, inverse: \FileAttachment.section)
    var attachments: [FileAttachment]

    init(order: Int = 0, sectionType: SectionType = .text, content: String = "") {
        self.order = order
        self.sectionTypeRaw = sectionType.rawValue
        self.content = content
        self.addedAt = .now
        self.lastEditedAt = .now
        self.attachments = []
    }

    var sectionType: SectionType {
        get { SectionType(rawValue: sectionTypeRaw) ?? .text }
        set { sectionTypeRaw = newValue.rawValue }
    }
}

// MARK: - File Attachment

enum FileType: String, CaseIterable, Identifiable, Codable {
    case image = "Image"
    case pdf = "PDF"
    case document = "Document"
    case spreadsheet = "Spreadsheet"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .document: return "doc.text"
        case .spreadsheet: return "tablecells"
        case .other: return "doc"
        }
    }

    static func from(extension ext: String) -> FileType {
        switch ext.lowercased() {
        case "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp": return .image
        case "pdf": return .pdf
        case "doc", "docx", "rtf", "txt", "pages", "odt": return .document
        case "xls", "xlsx", "csv", "numbers": return .spreadsheet
        default: return .other
        }
    }
}

@Model
final class FileAttachment {
    var filename: String
    var fileTypeRaw: String
    var addedAt: Date
    var notes: String
    var originalPath: String
    var fileSizeBytes: Int64

    @Attribute(.externalStorage) var fileData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?

    var section: ReportSection?
    var incident: Incident?

    init(filename: String, fileType: FileType, fileData: Data?, originalPath: String = "", notes: String = "") {
        self.filename = filename
        self.fileTypeRaw = fileType.rawValue
        self.fileData = fileData
        self.originalPath = originalPath
        self.notes = notes
        self.addedAt = .now
        self.fileSizeBytes = Int64(fileData?.count ?? 0)
    }

    var fileType: FileType {
        get { FileType(rawValue: fileTypeRaw) ?? .other }
        set { fileTypeRaw = newValue.rawValue }
    }
    var isImage: Bool { fileType == .image }

    var formattedSize: String {
        let bytes = Double(fileSizeBytes)
        if bytes < 1024 { return "\(fileSizeBytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", bytes / 1024) }
        return String(format: "%.1f MB", bytes / (1024 * 1024))
    }
}
