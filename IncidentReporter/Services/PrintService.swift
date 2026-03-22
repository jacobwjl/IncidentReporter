import AppKit
import SwiftUI

// MARK: - Document Renderer

class DocumentView: NSView {
    let report: Report
    let incident: Incident?
    private var totalPages = 1

    // Read settings from UserDefaults at render time
    private let orgName: String
    private let orgAddress: String
    private let headerAlignment: String
    private let showOrgNameInHeader: Bool
    private let showOrgAddressInHeader: Bool
    private let headerSeparatorStyle: String
    private let customFooterText: String
    private let customWatermarkText: String

    init(report: Report, incident: Incident?) {
        self.report = report
        self.incident = incident

        let defaults = UserDefaults.standard
        self.orgName = defaults.string(forKey: "orgName") ?? ""
        self.orgAddress = defaults.string(forKey: "orgAddress") ?? ""
        self.headerAlignment = defaults.string(forKey: "headerAlignment") ?? "left"
        self.showOrgNameInHeader = defaults.object(forKey: "showOrgNameInHeader") as? Bool ?? true
        self.showOrgAddressInHeader = defaults.object(forKey: "showOrgAddressInHeader") as? Bool ?? true
        self.headerSeparatorStyle = defaults.string(forKey: "headerSeparatorStyle") ?? "line"
        self.customFooterText = defaults.string(forKey: "customFooterText") ?? ""
        self.customWatermarkText = defaults.string(forKey: "customWatermarkText") ?? ""

        super.init(frame: NSRect(x: 0, y: 0, width: PageLayout.pageWidth, height: PageLayout.pageHeight))
        calculatePages()
    }

    required init?(coder: NSCoder) { nil }

    private var orgHeaderHeight: CGFloat {
        let showOrg = showOrgNameInHeader && !orgName.isEmpty
        let showAddr = showOrgAddressInHeader && !orgAddress.isEmpty
        if !showOrg && !showAddr { return 0 }
        var h: CGFloat = 8 // bottom padding
        if showOrg { h += 18 } // org name line
        if showAddr { h += 14 } // address line
        if headerSeparatorStyle == "doubleLine" { h += 8 }
        else if headerSeparatorStyle == "line" { h += 6 }
        h += 12 // spacing below separator
        return h
    }

    private func calculatePages() {
        let content = buildAttributedContent()
        let textHeight = content.boundingRect(
            with: NSSize(width: PageLayout.contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).height

        let headerHeight: CGFloat = (report.includeHeader && incident != nil) ? 120 : 0
        let dateHeight: CGFloat = report.includeDate ? 24 : 0
        let titleHeight: CGFloat = report.title.isEmpty ? 0 : 40
        let overhead = orgHeaderHeight + headerHeight + dateHeight + titleHeight + 20

        let available = PageLayout.contentHeight - overhead
        if textHeight <= available {
            totalPages = 1
        } else {
            totalPages = 1 + Int(ceil((textHeight - available) / (PageLayout.contentHeight - 20)))
        }

        self.frame = NSRect(x: 0, y: 0, width: PageLayout.pageWidth, height: PageLayout.pageHeight * CGFloat(totalPages))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(dirtyRect)

        let content = buildAttributedContent()

        for page in 0..<totalPages {
            let pageOrigin = CGFloat(page) * PageLayout.pageHeight
            let pageRect = NSRect(x: 0, y: pageOrigin, width: PageLayout.pageWidth, height: PageLayout.pageHeight)
            guard pageRect.intersects(dirtyRect) else { continue }

            if page == 0 {
                drawFirstPage(in: pageRect, context: ctx)
            }

            // Watermark
            if !customWatermarkText.isEmpty {
                drawWatermark(in: pageRect, context: ctx)
            }

            // Page number
            if report.includePageNumbers {
                let str = NSAttributedString(string: "Page \(page + 1) of \(totalPages)", attributes: [
                    .font: AppFonts.caption(size: 9),
                    .foregroundColor: NSColor.gray
                ])
                let size = str.size()
                str.draw(at: NSPoint(x: (PageLayout.pageWidth - size.width) / 2, y: pageOrigin + PageLayout.marginBottom - 25))
            }

            // Bates
            if report.includeBatesNumbers {
                let bates = NSAttributedString(string: report.batesNumber(for: page + 1), attributes: [
                    .font: AppFonts.mono(size: 8),
                    .foregroundColor: NSColor.gray
                ])
                bates.draw(at: NSPoint(x: PageLayout.marginLeft, y: pageOrigin + PageLayout.marginBottom - 25))
            }

            // Confidentiality
            if !report.confidentialityNotice.isEmpty {
                let notice = NSAttributedString(string: report.confidentialityNotice, attributes: [
                    .font: AppFonts.bodyBold(size: 7),
                    .foregroundColor: NSColor.red.withAlphaComponent(0.6)
                ])
                let size = notice.size()
                notice.draw(at: NSPoint(x: (PageLayout.pageWidth - size.width) / 2, y: pageOrigin + PageLayout.marginBottom - 40))
            }

            // Custom footer text
            if !customFooterText.isEmpty {
                let footer = NSAttributedString(string: customFooterText, attributes: [
                    .font: AppFonts.caption(size: 8),
                    .foregroundColor: NSColor.gray
                ])
                let size = footer.size()
                let footerY: CGFloat = report.confidentialityNotice.isEmpty
                    ? pageOrigin + PageLayout.marginBottom - 40
                    : pageOrigin + PageLayout.marginBottom - 52
                footer.draw(at: NSPoint(x: (PageLayout.pageWidth - size.width) / 2, y: footerY))
            }
        }

        drawContent(content)
    }

    // MARK: - Watermark

    private func drawWatermark(in pageRect: NSRect, context: CGContext) {
        context.saveGState()

        let centerX = pageRect.midX
        let centerY = pageRect.midY

        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: -.pi / 4) // -45 degrees

        let watermarkAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 72, weight: .bold),
            .foregroundColor: NSColor.gray.withAlphaComponent(0.08)
        ]
        let watermark = NSAttributedString(string: customWatermarkText.uppercased(), attributes: watermarkAttrs)
        let size = watermark.size()
        watermark.draw(at: NSPoint(x: -size.width / 2, y: -size.height / 2))

        context.restoreGState()
    }

    // MARK: - Organization Header Drawing

    private func drawOrgHeader(at startY: CGFloat, context: CGContext) -> CGFloat {
        let showOrg = showOrgNameInHeader && !orgName.isEmpty
        let showAddr = showOrgAddressInHeader && !orgAddress.isEmpty
        guard showOrg || showAddr else { return startY }

        var y = startY
        let contentWidth = PageLayout.contentWidth

        // Determine x position based on alignment
        func xForText(_ textWidth: CGFloat) -> CGFloat {
            switch headerAlignment {
            case "center":
                return PageLayout.marginLeft + (contentWidth - textWidth) / 2
            case "right":
                return PageLayout.marginLeft + contentWidth - textWidth
            default:
                return PageLayout.marginLeft
            }
        }

        if showOrg {
            let orgAttrs: [NSAttributedString.Key: Any] = [
                .font: AppFonts.bodyBold(size: 13),
                .foregroundColor: NSColor.black
            ]
            let orgStr = NSAttributedString(string: orgName, attributes: orgAttrs)
            let orgSize = orgStr.size()
            y -= orgSize.height + 2
            orgStr.draw(at: NSPoint(x: xForText(orgSize.width), y: y))
        }

        if showAddr {
            let addrAttrs: [NSAttributedString.Key: Any] = [
                .font: AppFonts.caption(size: 10),
                .foregroundColor: NSColor.gray
            ]
            let addrStr = NSAttributedString(string: orgAddress, attributes: addrAttrs)
            let addrSize = addrStr.size()
            y -= addrSize.height + 2
            addrStr.draw(at: NSPoint(x: xForText(addrSize.width), y: y))
        }

        y -= 6

        // Draw separator
        switch headerSeparatorStyle {
        case "line":
            context.setStrokeColor(NSColor.gray.withAlphaComponent(0.4).cgColor)
            context.setLineWidth(0.75)
            context.move(to: CGPoint(x: PageLayout.marginLeft, y: y))
            context.addLine(to: CGPoint(x: PageLayout.pageWidth - PageLayout.marginRight, y: y))
            context.strokePath()
            y -= 8
        case "doubleLine":
            context.setStrokeColor(NSColor.gray.withAlphaComponent(0.4).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: PageLayout.marginLeft, y: y))
            context.addLine(to: CGPoint(x: PageLayout.pageWidth - PageLayout.marginRight, y: y))
            context.strokePath()
            context.move(to: CGPoint(x: PageLayout.marginLeft, y: y - 3))
            context.addLine(to: CGPoint(x: PageLayout.pageWidth - PageLayout.marginRight, y: y - 3))
            context.strokePath()
            y -= 10
        default: // "none"
            y -= 4
        }

        return y
    }

    private func drawFirstPage(in pageRect: NSRect, context: CGContext) {
        var y = pageRect.maxY - PageLayout.marginTop

        // Organization header
        y = drawOrgHeader(at: y, context: context)

        // Header box
        if report.includeHeader, let incident {
            y = drawHeaderBox(at: y, incident: incident, context: context)
            y -= 16
        }

        // Title
        if !report.title.isEmpty {
            let titleStyle = NSMutableParagraphStyle()
            switch headerAlignment {
            case "center": titleStyle.alignment = .center
            case "right": titleStyle.alignment = .right
            default: titleStyle.alignment = .left
            }

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: AppFonts.title(size: 16),
                .foregroundColor: NSColor.black,
                .paragraphStyle: titleStyle
            ]
            let title = NSAttributedString(string: report.title.uppercased(), attributes: titleAttrs)
            y -= 20
            let titleRect = NSRect(x: PageLayout.marginLeft, y: y, width: PageLayout.contentWidth, height: 20)
            title.draw(in: titleRect)
            y -= 6

            // Underline
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: PageLayout.marginLeft, y: y))
            context.addLine(to: CGPoint(x: PageLayout.pageWidth - PageLayout.marginRight, y: y))
            context.strokePath()
            y -= 14
        }

        // Date + Reported by
        if report.includeDate || !report.reportedBy.isEmpty {
            let smallAttrs: [NSAttributedString.Key: Any] = [
                .font: AppFonts.caption(size: 9),
                .foregroundColor: NSColor.gray
            ]
            if report.includeDate {
                NSAttributedString(string: "Date: \(Date.now.dateFormatted)", attributes: smallAttrs)
                    .draw(at: NSPoint(x: PageLayout.marginLeft, y: y))
            }
            if !report.reportedBy.isEmpty {
                let prep = NSAttributedString(string: "Reported by: \(report.reportedBy)", attributes: smallAttrs)
                let w = prep.size().width
                prep.draw(at: NSPoint(x: PageLayout.pageWidth - PageLayout.marginRight - w, y: y))
            }
            y -= 14
        }
    }

    private func drawHeaderBox(at startY: CGFloat, incident: Incident, context: CGContext) -> CGFloat {
        let x = PageLayout.marginLeft
        let w = PageLayout.contentWidth
        var lines: [(String, String)] = []

        if !incident.title.isEmpty {
            lines.append(("", incident.title))
        }
        if !incident.referenceNumber.isEmpty {
            lines.append(("Ref", incident.referenceNumber))
        }
        for field in incident.sortedFields where !field.value.isEmpty {
            lines.append((field.label, field.value))
        }

        let lineHeight: CGFloat = 15
        let padding: CGFloat = 10
        let boxHeight = CGFloat(lines.count) * lineHeight + padding * 2 + 4

        let boxRect = NSRect(x: x, y: startY - boxHeight, width: w, height: boxHeight)

        // Box background
        context.setFillColor(NSColor(white: 0.96, alpha: 1.0).cgColor)
        context.fill(boxRect)

        // Box border
        context.setStrokeColor(NSColor(white: 0.3, alpha: 1.0).cgColor)
        context.setLineWidth(0.75)
        context.stroke(boxRect)

        // Text
        var y = startY - padding - lineHeight
        for (label, value) in lines {
            if label.isEmpty {
                // Title line
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: AppFonts.bodyBold(size: 12),
                    .foregroundColor: NSColor.black
                ]
                NSAttributedString(string: value, attributes: attrs)
                    .draw(at: NSPoint(x: x + padding, y: y))
            } else {
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: AppFonts.bodyBold(size: 9),
                    .foregroundColor: NSColor.gray
                ]
                let valueAttrs: [NSAttributedString.Key: Any] = [
                    .font: AppFonts.body(size: 10),
                    .foregroundColor: NSColor.black
                ]
                NSAttributedString(string: "\(label):", attributes: labelAttrs)
                    .draw(at: NSPoint(x: x + padding, y: y))
                NSAttributedString(string: value, attributes: valueAttrs)
                    .draw(at: NSPoint(x: x + padding + 90, y: y))
            }
            y -= lineHeight
        }

        return startY - boxHeight
    }

    private func drawContent(_ content: NSAttributedString) {
        var overhead: CGFloat = 20
        if report.includeDate || !report.reportedBy.isEmpty { overhead += 28 }
        if !report.title.isEmpty { overhead += 40 }
        if report.includeHeader && incident != nil { overhead += 120 }
        overhead += orgHeaderHeight

        let textRect = NSRect(
            x: PageLayout.marginLeft,
            y: PageLayout.marginBottom,
            width: PageLayout.contentWidth,
            height: CGFloat(totalPages) * PageLayout.pageHeight - PageLayout.marginBottom - PageLayout.marginTop - overhead
        )
        content.draw(in: textRect)
    }

    // MARK: - Build Content

    private func buildAttributedContent() -> NSAttributedString {
        let result = NSMutableAttributedString()

        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = PageLayout.lineSpacing
        bodyStyle.paragraphSpacing = PageLayout.paragraphSpacing

        let headingStyle = NSMutableParagraphStyle()
        headingStyle.lineSpacing = 2
        headingStyle.paragraphSpacing = 6
        headingStyle.paragraphSpacingBefore = 18

        for section in report.sortedSections {
            switch section.sectionType {
            case .heading:
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: AppFonts.heading(size: 12),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: headingStyle
                ]
                result.append(NSAttributedString(string: "\(section.content.uppercased())\n", attributes: attrs))

            case .text:
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: AppFonts.body(size: 11),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: bodyStyle
                ]
                result.append(NSAttributedString(string: "\(section.content)\n\n", attributes: attrs))

            case .numberedList:
                let items = section.content.components(separatedBy: "\n").filter { !$0.isEmpty }
                let listStyle = NSMutableParagraphStyle()
                listStyle.lineSpacing = 4
                listStyle.paragraphSpacing = 4
                listStyle.headIndent = 28
                listStyle.firstLineHeadIndent = 0

                for (i, item) in items.enumerated() {
                    let numAttrs: [NSAttributedString.Key: Any] = [
                        .font: AppFonts.mono(size: 10),
                        .foregroundColor: NSColor.black,
                        .paragraphStyle: listStyle
                    ]
                    let textAttrs: [NSAttributedString.Key: Any] = [
                        .font: AppFonts.body(size: 11),
                        .foregroundColor: NSColor.black,
                        .paragraphStyle: listStyle
                    ]
                    result.append(NSAttributedString(string: "  \(i + 1). ", attributes: numAttrs))
                    result.append(NSAttributedString(string: "\(item)\n", attributes: textAttrs))
                }
                result.append(NSAttributedString(string: "\n", attributes: [.font: AppFonts.body(size: 6)]))

            case .infoBox:
                let boxStyle = NSMutableParagraphStyle()
                boxStyle.lineSpacing = 4
                boxStyle.paragraphSpacing = 6
                boxStyle.paragraphSpacingBefore = 8
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: AppFonts.body(size: 10),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: boxStyle,
                    .backgroundColor: NSColor(white: 0.96, alpha: 1.0)
                ]
                result.append(NSAttributedString(string: "  \(section.content)  \n\n", attributes: attrs))

            case .fileAttachment:
                let label = section.exhibitLabel ?? "Attachment"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: AppFonts.bodyBold(size: 11),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: bodyStyle
                ]
                result.append(NSAttributedString(string: "[\(label)]\n", attributes: attrs))
                for attachment in section.attachments {
                    let fileAttrs: [NSAttributedString.Key: Any] = [
                        .font: AppFonts.body(size: 10),
                        .foregroundColor: NSColor.darkGray,
                        .paragraphStyle: bodyStyle
                    ]
                    result.append(NSAttributedString(string: "  \(attachment.filename) (\(attachment.formattedSize))\n", attributes: fileAttrs))
                }
                if !section.content.isEmpty {
                    let descAttrs: [NSAttributedString.Key: Any] = [
                        .font: AppFonts.body(size: 10),
                        .foregroundColor: NSColor.darkGray,
                        .paragraphStyle: bodyStyle
                    ]
                    result.append(NSAttributedString(string: "\(section.content)\n", attributes: descAttrs))
                }
                result.append(NSAttributedString(string: "\n", attributes: [.font: AppFonts.body(size: 6)]))

            case .separator:
                let sepStyle = NSMutableParagraphStyle()
                sepStyle.paragraphSpacingBefore = 10
                sepStyle.paragraphSpacing = 10
                sepStyle.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: AppFonts.body(size: 10),
                    .foregroundColor: NSColor.lightGray,
                    .paragraphStyle: sepStyle
                ]
                result.append(NSAttributedString(string: "\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\n", attributes: attrs))

            case .signature:
                let sigStyle = NSMutableParagraphStyle()
                sigStyle.paragraphSpacingBefore = 40
                sigStyle.lineSpacing = 6
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: AppFonts.body(size: 11),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: sigStyle
                ]
                var block = "\n\n\n____________________________________\n"
                if !section.content.isEmpty { block += "\(section.content)\n" }
                block += "Date: ____________\n"
                result.append(NSAttributedString(string: block, attributes: attrs))

            case .checklist:
                let items = section.content.components(separatedBy: "\n").filter { !$0.isEmpty }
                let checklistStyle = NSMutableParagraphStyle()
                checklistStyle.lineSpacing = 4
                checklistStyle.paragraphSpacing = 4
                checklistStyle.headIndent = 28
                checklistStyle.firstLineHeadIndent = 0

                for item in items {
                    let isChecked = item.hasPrefix("[x] ")
                    let isUnchecked = item.hasPrefix("[ ] ")
                    let checkbox: String
                    let itemText: String

                    if isChecked {
                        checkbox = "\u{2611} "
                        itemText = String(item.dropFirst(4))
                    } else if isUnchecked {
                        checkbox = "\u{2610} "
                        itemText = String(item.dropFirst(4))
                    } else {
                        checkbox = "\u{2610} "
                        itemText = item
                    }

                    let checkAttrs: [NSAttributedString.Key: Any] = [
                        .font: AppFonts.body(size: 12),
                        .foregroundColor: NSColor.black,
                        .paragraphStyle: checklistStyle
                    ]
                    let textAttrs: [NSAttributedString.Key: Any] = [
                        .font: AppFonts.body(size: 11),
                        .foregroundColor: NSColor.black,
                        .paragraphStyle: checklistStyle
                    ]

                    result.append(NSAttributedString(string: "  \(checkbox)", attributes: checkAttrs))
                    result.append(NSAttributedString(string: "\(itemText)\n", attributes: textAttrs))
                }
                result.append(NSAttributedString(string: "\n", attributes: [.font: AppFonts.body(size: 6)]))

            case .table:
                let rows = section.content.components(separatedBy: "\n").filter { !$0.isEmpty }

                // Calculate the max first-column width for consistent tab stops
                var maxCol0Width: CGFloat = 120
                let measuringAttrs: [NSAttributedString.Key: Any] = [.font: AppFonts.bodyBold(size: 10)]
                for row in rows {
                    let cols = row.components(separatedBy: "\t")
                    if cols.count >= 2 {
                        let measured = (cols[0] as NSString).size(withAttributes: measuringAttrs).width + 16
                        if measured > maxCol0Width { maxCol0Width = measured }
                    }
                }

                // Cap the column width so the second column always has room
                maxCol0Width = min(maxCol0Width, PageLayout.contentWidth * 0.5)

                let tabStop = NSTextTab(textAlignment: .left, location: maxCol0Width)
                let tableStyle = NSMutableParagraphStyle()
                tableStyle.lineSpacing = 2
                tableStyle.paragraphSpacing = 2
                tableStyle.tabStops = [tabStop]
                tableStyle.headIndent = 8
                tableStyle.firstLineHeadIndent = 8

                for (index, row) in rows.enumerated() {
                    let cols = row.components(separatedBy: "\t")

                    if index == 0 && cols.count >= 2 {
                        // First row rendered bold as a header
                        let headerAttrs: [NSAttributedString.Key: Any] = [
                            .font: AppFonts.bodyBold(size: 10),
                            .foregroundColor: NSColor.black,
                            .paragraphStyle: tableStyle
                        ]
                        let headerLine = "\(cols[0])\t\(cols.dropFirst().joined(separator: "  "))\n"
                        result.append(NSAttributedString(string: headerLine, attributes: headerAttrs))

                        // Thin separator after header row
                        let sepLineStyle = NSMutableParagraphStyle()
                        sepLineStyle.paragraphSpacing = 2
                        sepLineStyle.alignment = .left
                        let sepAttrs: [NSAttributedString.Key: Any] = [
                            .font: AppFonts.body(size: 4),
                            .foregroundColor: NSColor.lightGray,
                            .paragraphStyle: sepLineStyle
                        ]
                        result.append(NSAttributedString(string: "  \(String(repeating: "\u{2500}", count: 50))\n", attributes: sepAttrs))
                    } else if cols.count >= 2 {
                        let rowAttrs: [NSAttributedString.Key: Any] = [
                            .font: AppFonts.body(size: 10),
                            .foregroundColor: NSColor.black,
                            .paragraphStyle: tableStyle
                        ]
                        let rowLine = "\(cols[0])\t\(cols.dropFirst().joined(separator: "  "))\n"
                        result.append(NSAttributedString(string: rowLine, attributes: rowAttrs))
                    } else {
                        let rowAttrs: [NSAttributedString.Key: Any] = [
                            .font: AppFonts.body(size: 10),
                            .foregroundColor: NSColor.black,
                            .paragraphStyle: tableStyle
                        ]
                        result.append(NSAttributedString(string: "  \(row)\n", attributes: rowAttrs))
                    }
                }
                result.append(NSAttributedString(string: "\n", attributes: [.font: AppFonts.body(size: 6)]))

            case .blockQuote:
                // Split content from optional attribution (separated by \n---\n)
                let parts = section.content.components(separatedBy: "\n---\n")
                let quoteText = parts[0]
                let attribution: String? = parts.count > 1
                    ? parts.dropFirst().joined(separator: "\n---\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    : nil

                let quoteStyle = NSMutableParagraphStyle()
                quoteStyle.lineSpacing = PageLayout.lineSpacing
                quoteStyle.paragraphSpacing = 4
                quoteStyle.headIndent = 32
                quoteStyle.firstLineHeadIndent = 32
                quoteStyle.paragraphSpacingBefore = 10

                // Build italic font for quote body
                let italicDescriptor = AppFonts.body(size: 11).fontDescriptor.withSymbolicTraits(.italic)
                let italicFont = NSFont(descriptor: italicDescriptor, size: 11) ?? AppFonts.body(size: 11)

                // Render each line with a left-border bar character
                let lines = quoteText.components(separatedBy: "\n")
                for (index, line) in lines.enumerated() {
                    let lineStyle: NSMutableParagraphStyle
                    if index == 0 {
                        lineStyle = quoteStyle.mutableCopy() as! NSMutableParagraphStyle
                    } else {
                        lineStyle = quoteStyle.mutableCopy() as! NSMutableParagraphStyle
                        lineStyle.paragraphSpacingBefore = 0
                    }

                    let barAttrs: [NSAttributedString.Key: Any] = [
                        .font: AppFonts.body(size: 11),
                        .foregroundColor: PrintColors.accentBlue,
                        .paragraphStyle: lineStyle
                    ]
                    let textAttrs: [NSAttributedString.Key: Any] = [
                        .font: italicFont,
                        .foregroundColor: NSColor(white: 0.2, alpha: 1.0),
                        .paragraphStyle: lineStyle
                    ]

                    result.append(NSAttributedString(string: "\u{2502} ", attributes: barAttrs))
                    result.append(NSAttributedString(string: "\(line)\n", attributes: textAttrs))
                }

                // Attribution line below the quote
                if let attribution, !attribution.isEmpty {
                    let attrStyle = NSMutableParagraphStyle()
                    attrStyle.headIndent = 32
                    attrStyle.firstLineHeadIndent = 32
                    attrStyle.paragraphSpacing = PageLayout.paragraphSpacing
                    attrStyle.paragraphSpacingBefore = 4

                    let attrAttrs: [NSAttributedString.Key: Any] = [
                        .font: AppFonts.caption(size: 9),
                        .foregroundColor: PrintColors.mutedText,
                        .paragraphStyle: attrStyle
                    ]
                    result.append(NSAttributedString(string: "  \u{2014} \(attribution)\n", attributes: attrAttrs))
                }

                result.append(NSAttributedString(string: "\n", attributes: [.font: AppFonts.body(size: 6)]))
            }
        }

        return result
    }

    // MARK: - Pagination

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        range.pointee = NSRange(location: 1, length: totalPages)
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        NSRect(x: 0, y: CGFloat(page - 1) * PageLayout.pageHeight, width: PageLayout.pageWidth, height: PageLayout.pageHeight)
    }
}

// MARK: - Print Service

@MainActor
struct PrintService {
    static func print(report: Report, incident: Incident?) {
        let docView = DocumentView(report: report, incident: incident)
        let printOp = NSPrintOperation(view: docView, printInfo: PageLayout.printInfo)
        printOp.showsPrintPanel = true
        printOp.showsProgressPanel = true
        printOp.run()
    }

    static func exportPDF(report: Report, incident: Incident?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(report.title.isEmpty ? "Report" : report.title).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let docView = DocumentView(report: report, incident: incident)
        let pdfData = docView.dataWithPDF(inside: docView.bounds)

        do {
            try pdfData.write(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
