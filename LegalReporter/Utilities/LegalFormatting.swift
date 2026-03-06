import SwiftUI
import AppKit

// MARK: - App Fonts (San Francisco)

struct AppFonts {
    static func title(size: CGFloat = 18) -> NSFont { .systemFont(ofSize: size, weight: .bold) }
    static func heading(size: CGFloat = 14) -> NSFont { .systemFont(ofSize: size, weight: .semibold) }
    static func body(size: CGFloat = 12) -> NSFont { .systemFont(ofSize: size, weight: .regular) }
    static func bodyBold(size: CGFloat = 12) -> NSFont { .systemFont(ofSize: size, weight: .semibold) }
    static func bodyMedium(size: CGFloat = 12) -> NSFont { .systemFont(ofSize: size, weight: .medium) }
    static func caption(size: CGFloat = 10) -> NSFont { .systemFont(ofSize: size, weight: .regular) }
    static func mono(size: CGFloat = 11) -> NSFont { .monospacedSystemFont(ofSize: size, weight: .regular) }

    static var swiftUITitle: Font { .system(size: 18, weight: .bold) }
    static var swiftUIHeading: Font { .system(size: 14, weight: .semibold) }
    static var swiftUIBody: Font { .system(size: 12) }
    static var swiftUICaption: Font { .system(size: 10) }
    static var swiftUIMono: Font { .system(size: 11, design: .monospaced) }
}

// MARK: - Page Layout

struct PageLayout {
    static let pageWidth: CGFloat = 612
    static let pageHeight: CGFloat = 792
    static let marginTop: CGFloat = 72
    static let marginBottom: CGFloat = 72
    static let marginLeft: CGFloat = 72
    static let marginRight: CGFloat = 72

    static let contentWidth: CGFloat = pageWidth - marginLeft - marginRight
    static let contentHeight: CGFloat = pageHeight - marginTop - marginBottom

    static let lineSpacing: CGFloat = 6
    static let paragraphSpacing: CGFloat = 10
    static let sectionSpacing: CGFloat = 16

    static var printInfo: NSPrintInfo {
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.paperSize = NSSize(width: pageWidth, height: pageHeight)
        info.topMargin = marginTop
        info.bottomMargin = marginBottom
        info.leftMargin = marginLeft
        info.rightMargin = marginRight
        info.isHorizontallyCentered = true
        info.isVerticallyCentered = false
        return info
    }
}

// MARK: - Colors for print

struct PrintColors {
    static let headerBackground = NSColor(white: 0.95, alpha: 1.0)
    static let boxBorder = NSColor(white: 0.3, alpha: 1.0)
    static let ruleLine = NSColor(white: 0.6, alpha: 1.0)
    static let accentBlue = NSColor(red: 0.15, green: 0.35, blue: 0.6, alpha: 1.0)
    static let mutedText = NSColor(white: 0.4, alpha: 1.0)
}

// MARK: - Status & Priority Colors

extension CaseStatus {
    var color: Color {
        switch self {
        case .open: return .blue
        case .active: return .green
        case .underReview: return .orange
        case .closed: return .gray
        case .archived: return .secondary
        }
    }
}

extension CasePriority {
    var color: Color {
        switch self {
        case .none: return .secondary
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

// MARK: - Tag Color Helpers

extension TagColor {
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return .teal
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .gray: return .gray
        }
    }
}

extension Tag {
    var color: Color {
        tagColor?.color ?? .blue
    }
}

// MARK: - Date Formatting

extension Date {
    var legalFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: self)
    }

    var shortLegal: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: self)
    }

    var timestampFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        return formatter.string(from: self)
    }

    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

// MARK: - Deadline Urgency

extension Deadline {
    var urgencyColor: Color {
        if isCompleted { return .green }
        if isOverdue { return .red }
        if isDueSoon { return .orange }
        return .secondary
    }

    var urgencyIcon: String {
        if isCompleted { return "checkmark.circle.fill" }
        if isOverdue { return "exclamationmark.circle.fill" }
        if isDueSoon { return "clock.fill" }
        return "clock"
    }
}
