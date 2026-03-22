import SwiftUI
import AppKit

// MARK: - Theme Enums

enum HeaderBoxStyle: String {
    case bordered       // Standard bordered box (Maintenance, Vehicle, Property)
    case accentBar      // Thick colored left bar (Safety, Environmental)
    case minimal        // No border/background (Security, Other)
    case shaded         // Deeper tinted background (Workplace, Health)
}

enum HeadingRenderStyle: String {
    case underline      // Text + thin rule below (General, Property)
    case allCaps        // Uppercase with wide tracking (Safety, Maintenance)
    case accentSidebar  // Thick colored left bar (Environmental, Health)
    case bold           // Just bold text, no decoration (Security, Other)
}

// MARK: - Category Theme

struct CategoryTheme {
    let category: IncidentCategory
    let icon: String
    let accentColor: Color
    let nsAccentColor: NSColor

    let headingDesign: Font.Design
    let bodyDesign: Font.Design
    let headingWeight: Font.Weight
    let headingTracking: CGFloat
    let uppercaseHeadings: Bool

    let headerBoxStyle: HeaderBoxStyle
    let headingStyle: HeadingRenderStyle

    let documentLabel: String

    // MARK: - NSFont Helpers (Print Path)

    func nsHeading(size: CGFloat) -> NSFont {
        fontForDesign(headingDesign, size: size, weight: nsWeight(headingWeight))
    }

    func nsBody(size: CGFloat) -> NSFont {
        fontForDesign(bodyDesign, size: size, weight: .regular)
    }

    func nsCaption(size: CGFloat) -> NSFont {
        .systemFont(ofSize: size, weight: .regular)
    }

    // MARK: - Print Colors (derived from accent)

    var printAccent: NSColor { nsAccentColor }

    var printHeadingColor: NSColor {
        switch category {
        case .security: return NSColor(white: 0.15, alpha: 1.0)
        default: return .black
        }
    }

    var printHeaderBackground: NSColor {
        switch headerBoxStyle {
        case .shaded: return nsAccentColor.withAlphaComponent(0.06)
        case .bordered, .accentBar: return NSColor(white: 0.96, alpha: 1.0)
        case .minimal: return .clear
        }
    }

    var printHeaderBorder: NSColor {
        switch headerBoxStyle {
        case .bordered: return NSColor(white: 0.3, alpha: 1.0)
        case .accentBar: return nsAccentColor.withAlphaComponent(0.3)
        case .shaded: return nsAccentColor.withAlphaComponent(0.15)
        case .minimal: return .clear
        }
    }

    var printRuleColor: NSColor {
        nsAccentColor.withAlphaComponent(0.3)
    }

    // MARK: - SwiftUI Font Helpers

    var swiftUIHeadingFont: Font {
        .system(size: 12, weight: headingWeight, design: headingDesign)
    }

    var swiftUIBodyFont: Font {
        .system(size: 11, design: bodyDesign)
    }

    // MARK: - Private Helpers

    private func fontForDesign(_ design: Font.Design, size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let baseDescriptor = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor

        let systemDesign: NSFontDescriptor.SystemDesign
        switch design {
        case .serif: systemDesign = .serif
        case .monospaced: systemDesign = .monospaced
        case .rounded: systemDesign = .rounded
        default: systemDesign = .default
        }

        if let designedDescriptor = baseDescriptor.withDesign(systemDesign) {
            return NSFont(descriptor: designedDescriptor, size: size) ?? .systemFont(ofSize: size, weight: weight)
        }
        return .systemFont(ofSize: size, weight: weight)
    }

    private func nsWeight(_ weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
}

// MARK: - Theme Definitions

extension IncidentCategory {
    var theme: CategoryTheme {
        switch self {
        case .safety:
            return CategoryTheme(
                category: self,
                icon: "exclamationmark.shield.fill",
                accentColor: Color(red: 0.90, green: 0.55, blue: 0.05),
                nsAccentColor: NSColor(red: 0.90, green: 0.55, blue: 0.05, alpha: 1.0),
                headingDesign: .default,
                bodyDesign: .default,
                headingWeight: .bold,
                headingTracking: 1.5,
                uppercaseHeadings: true,
                headerBoxStyle: .accentBar,
                headingStyle: .allCaps,
                documentLabel: "SAFETY INCIDENT REPORT"
            )
        case .security:
            return CategoryTheme(
                category: self,
                icon: "lock.shield.fill",
                accentColor: Color(red: 0.20, green: 0.25, blue: 0.42),
                nsAccentColor: NSColor(red: 0.20, green: 0.25, blue: 0.42, alpha: 1.0),
                headingDesign: .default,
                bodyDesign: .default,
                headingWeight: .semibold,
                headingTracking: 0.5,
                uppercaseHeadings: true,
                headerBoxStyle: .minimal,
                headingStyle: .bold,
                documentLabel: "SECURITY REPORT"
            )
        case .maintenance:
            return CategoryTheme(
                category: self,
                icon: "wrench.and.screwdriver.fill",
                accentColor: .teal,
                nsAccentColor: .systemTeal,
                headingDesign: .default,
                bodyDesign: .default,
                headingWeight: .semibold,
                headingTracking: 0.8,
                uppercaseHeadings: true,
                headerBoxStyle: .bordered,
                headingStyle: .allCaps,
                documentLabel: "MAINTENANCE WORK ORDER"
            )
        case .environmental:
            return CategoryTheme(
                category: self,
                icon: "leaf.fill",
                accentColor: Color(red: 0.15, green: 0.50, blue: 0.25),
                nsAccentColor: NSColor(red: 0.15, green: 0.50, blue: 0.25, alpha: 1.0),
                headingDesign: .default,
                bodyDesign: .serif,
                headingWeight: .semibold,
                headingTracking: 0.3,
                uppercaseHeadings: false,
                headerBoxStyle: .accentBar,
                headingStyle: .accentSidebar,
                documentLabel: "Environmental Incident Report"
            )
        case .health:
            return CategoryTheme(
                category: self,
                icon: "cross.case.fill",
                accentColor: Color(red: 0.20, green: 0.50, blue: 0.85),
                nsAccentColor: NSColor(red: 0.20, green: 0.50, blue: 0.85, alpha: 1.0),
                headingDesign: .serif,
                bodyDesign: .default,
                headingWeight: .semibold,
                headingTracking: 0.2,
                uppercaseHeadings: false,
                headerBoxStyle: .shaded,
                headingStyle: .accentSidebar,
                documentLabel: "Health Incident Report"
            )
        case .workplace:
            return CategoryTheme(
                category: self,
                icon: "person.2.fill",
                accentColor: Color(red: 0.35, green: 0.30, blue: 0.65),
                nsAccentColor: NSColor(red: 0.35, green: 0.30, blue: 0.65, alpha: 1.0),
                headingDesign: .serif,
                bodyDesign: .default,
                headingWeight: .semibold,
                headingTracking: 0.3,
                uppercaseHeadings: false,
                headerBoxStyle: .shaded,
                headingStyle: .underline,
                documentLabel: "Workplace Incident Report"
            )
        case .vehicle:
            return CategoryTheme(
                category: self,
                icon: "car.fill",
                accentColor: Color(red: 0.40, green: 0.45, blue: 0.50),
                nsAccentColor: NSColor(red: 0.40, green: 0.45, blue: 0.50, alpha: 1.0),
                headingDesign: .default,
                bodyDesign: .default,
                headingWeight: .semibold,
                headingTracking: 0.5,
                uppercaseHeadings: true,
                headerBoxStyle: .bordered,
                headingStyle: .underline,
                documentLabel: "VEHICLE INCIDENT REPORT"
            )
        case .property:
            return CategoryTheme(
                category: self,
                icon: "building.fill",
                accentColor: Color(red: 0.55, green: 0.38, blue: 0.22),
                nsAccentColor: NSColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1.0),
                headingDesign: .default,
                bodyDesign: .default,
                headingWeight: .semibold,
                headingTracking: 0.3,
                uppercaseHeadings: false,
                headerBoxStyle: .bordered,
                headingStyle: .underline,
                documentLabel: "Property Damage Report"
            )
        case .general:
            return CategoryTheme(
                category: self,
                icon: "doc.text.fill",
                accentColor: .blue,
                nsAccentColor: .systemBlue,
                headingDesign: .default,
                bodyDesign: .default,
                headingWeight: .bold,
                headingTracking: 0.5,
                uppercaseHeadings: true,
                headerBoxStyle: .bordered,
                headingStyle: .underline,
                documentLabel: "INCIDENT REPORT"
            )
        case .other:
            return CategoryTheme(
                category: self,
                icon: "folder.fill",
                accentColor: .gray,
                nsAccentColor: .systemGray,
                headingDesign: .default,
                bodyDesign: .default,
                headingWeight: .semibold,
                headingTracking: 0,
                uppercaseHeadings: false,
                headerBoxStyle: .minimal,
                headingStyle: .bold,
                documentLabel: "Report"
            )
        }
    }
}
