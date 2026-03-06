import SwiftUI
import AppKit

struct ReportPreviewView: View {
    let report: Report
    let legalCase: LegalCase?

    @AppStorage("firmName") private var firmName = ""
    @AppStorage("firmAddress") private var firmAddress = ""
    @AppStorage("headerAlignment") private var headerAlignment = "left"
    @AppStorage("showFirmNameInHeader") private var showFirmNameInHeader = true
    @AppStorage("showFirmAddressInHeader") private var showFirmAddressInHeader = true
    @AppStorage("headerSeparatorStyle") private var headerSeparatorStyle = "line"
    @AppStorage("customFooterText") private var customFooterText = ""
    @AppStorage("customWatermarkText") private var customWatermarkText = ""

    private var resolvedAlignment: HorizontalAlignment {
        switch headerAlignment {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    private var resolvedTextAlignment: TextAlignment {
        switch headerAlignment {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    private var resolvedFrameAlignment: Alignment {
        switch headerAlignment {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Simulated printed page
                ZStack {
                    VStack(alignment: .leading, spacing: 0) {
                        // Firm header
                        firmHeader

                        // Header box
                        if report.includeHeader, let legalCase {
                            headerBox(legalCase)
                                .padding(.bottom, 16)
                        }

                        // Report title
                        if !report.title.isEmpty {
                            Text(report.title.uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .tracking(1)
                                .padding(.bottom, 4)

                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 2)
                                .padding(.bottom, 14)
                        }

                        // Date + Prepared by line
                        if report.includeDate || !report.preparedBy.isEmpty {
                            HStack {
                                if report.includeDate {
                                    Text("Date: \(Date.now.legalFormatted)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.black.opacity(0.6))
                                }
                                Spacer()
                                if !report.preparedBy.isEmpty {
                                    Text("Prepared by: \(report.preparedBy)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.black.opacity(0.6))
                                }
                            }
                            .padding(.bottom, 14)
                        }

                        // Sections
                        ForEach(report.sortedSections) { section in
                            sectionView(section)
                        }

                        Spacer(minLength: 20)

                        // Confidentiality notice
                        if !report.confidentialityNotice.isEmpty {
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(height: 0.5)
                                .padding(.vertical, 8)

                            Text(report.confidentialityNotice)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(72)

                    // Watermark overlay
                    if !customWatermarkText.isEmpty {
                        Text(customWatermarkText.uppercased())
                            .font(.system(size: 64, weight: .bold))
                            .foregroundStyle(.gray.opacity(0.12))
                            .rotationEffect(.degrees(-45))
                            .allowsHitTesting(false)
                    }
                }
                .background(.white)
                .foregroundStyle(.black)
                .frame(width: 612)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

                // Footer
                footer
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Firm Header

    @ViewBuilder
    private var firmHeader: some View {
        let showFirm = showFirmNameInHeader && !firmName.isEmpty
        let showAddr = showFirmAddressInHeader && !firmAddress.isEmpty

        if showFirm || showAddr {
            VStack(alignment: resolvedAlignment, spacing: 3) {
                if showFirm {
                    Text(firmName)
                        .font(.system(size: 13, weight: .bold))
                        .multilineTextAlignment(resolvedTextAlignment)
                }
                if showAddr {
                    Text(firmAddress)
                        .font(.system(size: 10))
                        .foregroundStyle(.black.opacity(0.6))
                        .multilineTextAlignment(resolvedTextAlignment)
                }
            }
            .frame(maxWidth: .infinity, alignment: resolvedFrameAlignment)
            .padding(.bottom, 8)

            // Header separator
            headerSeparator
                .padding(.bottom, 12)
        }
    }

    // MARK: - Header Separator

    @ViewBuilder
    private var headerSeparator: some View {
        switch headerSeparatorStyle {
        case "doubleLine":
            VStack(spacing: 2) {
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(height: 1)
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(height: 1)
            }
        case "none":
            EmptyView()
        default: // "line"
            Rectangle()
                .fill(Color.black.opacity(0.4))
                .frame(height: 1)
        }
    }

    // MARK: - Header Box

    private func headerBox(_ legalCase: LegalCase) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(legalCase.title.isEmpty ? "Untitled" : legalCase.title)
                .font(.system(size: 13, weight: .bold))

            if !legalCase.referenceNumber.isEmpty {
                HStack(spacing: 4) {
                    Text("Ref:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.5))
                    Text(legalCase.referenceNumber)
                        .font(.system(size: 10, design: .monospaced))
                }
            }

            if !legalCase.sortedFields.isEmpty {
                Rectangle()
                    .fill(Color.black.opacity(0.15))
                    .frame(height: 0.5)
                    .padding(.vertical, 2)

                ForEach(legalCase.sortedFields) { field in
                    if !field.value.isEmpty {
                        HStack(alignment: .top, spacing: 4) {
                            Text("\(field.label):")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.5))
                                .frame(width: 100, alignment: .trailing)
                            Text(field.value)
                                .font(.system(size: 10))
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.black.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Section Views

    @ViewBuilder
    private func sectionView(_ section: ReportSection) -> some View {
        switch section.sectionType {
        case .heading:
            VStack(alignment: .leading, spacing: 3) {
                Text(section.content.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.5)
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 0.5)
            }
            .padding(.top, 18)
            .padding(.bottom, 8)

        case .text:
            Text(section.content)
                .font(.system(size: 11))
                .lineSpacing(6)
                .textSelection(.enabled)
                .padding(.bottom, 10)

        case .numberedList:
            let items = section.content.components(separatedBy: "\n").filter { !$0.isEmpty }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .frame(width: 24, alignment: .trailing)
                        Text(item)
                            .font(.system(size: 11))
                            .lineSpacing(4)
                    }
                }
            }
            .padding(.bottom, 10)

        case .infoBox:
            VStack(alignment: .leading, spacing: 4) {
                Text(section.content)
                    .font(.system(size: 11))
                    .lineSpacing(5)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.black.opacity(0.25), lineWidth: 1)
            )
            .padding(.vertical, 6)

        case .fileAttachment:
            fileAttachmentPreview(section)
                .padding(.vertical, 6)

        case .separator:
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(height: 1)
                .padding(.vertical, 12)

        case .signature:
            VStack(alignment: .leading, spacing: 4) {
                Spacer().frame(height: 36)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 240, height: 1)
                if !section.content.isEmpty {
                    Text(section.content)
                        .font(.system(size: 11))
                }
                Text("Date: ____________")
                    .font(.system(size: 11))
            }
            .padding(.top, 16)

        case .checklist:
            checklistPreview(section)
                .padding(.bottom, 10)

        case .table:
            tablePreview(section)
                .padding(.vertical, 6)

        case .blockQuote:
            blockQuotePreview(section)
                .padding(.vertical, 6)
        }
    }

    // MARK: - Checklist Preview

    private func checklistPreview(_ section: ReportSection) -> some View {
        let items = section.content.components(separatedBy: "\n").filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    if item.hasPrefix("[x] ") {
                        Text("\u{2611}")
                            .font(.system(size: 12))
                            .frame(width: 18, alignment: .center)
                        Text(String(item.dropFirst(4)))
                            .font(.system(size: 11))
                            .strikethrough(true, color: .black.opacity(0.3))
                            .foregroundStyle(.black.opacity(0.5))
                            .lineSpacing(4)
                    } else {
                        let displayText: String = item.hasPrefix("[ ] ") ? String(item.dropFirst(4)) : item
                        Text("\u{2610}")
                            .font(.system(size: 12))
                            .frame(width: 18, alignment: .center)
                        Text(displayText)
                            .font(.system(size: 11))
                            .lineSpacing(4)
                    }
                }
            }
        }
    }

    // MARK: - Table Preview

    private func tablePreview(_ section: ReportSection) -> some View {
        let rows = section.content.components(separatedBy: "\n").compactMap { line -> (key: String, value: String)? in
            guard !line.isEmpty else { return nil }
            let parts = line.components(separatedBy: "\t")
            if parts.count >= 2 {
                return (key: parts[0], value: parts.dropFirst().joined(separator: " "))
            }
            return (key: parts[0], value: "")
        }

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack(spacing: 0) {
                    Text(row.key)
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 160, alignment: .leading)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(idx % 2 == 0 ? 0.04 : 0.02))

                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 0.5)

                    Text(row.value)
                        .font(.system(size: 10))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(idx % 2 == 0 ? 0.04 : 0.02))
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    // MARK: - Block Quote Preview

    private func blockQuotePreview(_ section: ReportSection) -> some View {
        let lines = section.content.components(separatedBy: "\n")
        let hasAttribution = lines.last?.hasPrefix("-- ") ?? false
        let quoteLines = hasAttribution ? lines.dropLast() : ArraySlice(lines)
        let quoteText = quoteLines.joined(separator: "\n")
        let attribution: String = {
            guard hasAttribution, let last = lines.last else { return "" }
            return String(last.dropFirst(3))
        }()

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.black.opacity(0.25))
                    .frame(width: 3)

                Text(quoteText)
                    .font(.system(size: 11))
                    .italic()
                    .lineSpacing(5)
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(.leading, 10)
            }

            if !attribution.isEmpty {
                Text("\u{2014} \(attribution)")
                    .font(.system(size: 10))
                    .foregroundStyle(.black.opacity(0.5))
                    .padding(.leading, 13)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - File Attachment Preview

    private func fileAttachmentPreview(_ section: ReportSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("[\(section.exhibitLabel ?? "Attachment")]")
                .font(.system(size: 11, weight: .bold))

            ForEach(section.attachments.sorted(by: { $0.addedAt < $1.addedAt })) { attachment in
                if attachment.isImage, let data = attachment.thumbnailData ?? attachment.fileData,
                   let image = NSImage(data: data) {
                    VStack(alignment: .leading, spacing: 2) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 380, maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.black.opacity(0.15), lineWidth: 0.5))
                        Text(attachment.filename)
                            .font(.system(size: 8))
                            .foregroundStyle(.black.opacity(0.4))
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: attachment.fileType.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(.black.opacity(0.4))
                        Text(attachment.filename)
                            .font(.system(size: 10))
                        Text("(\(attachment.formattedSize))")
                            .font(.system(size: 9))
                            .foregroundStyle(.black.opacity(0.4))
                    }
                }
            }

            if !section.content.isEmpty {
                Text(section.content)
                    .font(.system(size: 10))
                    .foregroundStyle(.black.opacity(0.6))
                    .lineSpacing(4)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 2) {
            HStack {
                if report.includeBatesNumbers {
                    Text(report.batesNumber(for: 1))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if report.includePageNumbers {
                    Text("Page 1 of 1")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if report.includeBatesNumbers {
                    Text(report.batesNumber(for: 1))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.clear) // balance
                }
            }

            if !customFooterText.isEmpty {
                Text(customFooterText)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(width: 612)
        .padding(.horizontal, 72)
        .padding(.top, 4)
    }
}
