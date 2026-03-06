import SwiftUI
import SwiftData
import AppKit

// MARK: - Preview Panel Manager

@MainActor
final class PreviewPanelManager: ObservableObject {
    private var panel: NSPanel?
    private var closeObserver: NSObjectProtocol?

    var isOpen: Bool { panel != nil }

    func open(report: Report, legalCase: LegalCase?) {
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let previewView = ReportPreviewView(report: report, legalCase: legalCase)
        let hostingView = NSHostingView(rootView: previewView)

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 700),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.title = report.title.isEmpty ? "Report Preview" : "Preview \u{2014} \(report.title)"
        newPanel.isFloatingPanel = true
        newPanel.hidesOnDeactivate = false
        newPanel.contentView = hostingView
        newPanel.isReleasedWhenClosed = false
        newPanel.center()
        newPanel.setFrameAutosaveName("ReportPreviewPanel")
        newPanel.contentMinSize = NSSize(width: 500, height: 400)
        newPanel.makeKeyAndOrderFront(nil)

        // Watch for close so we can clear state
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: newPanel,
            queue: .main
        ) { [weak self] _ in
            self?.panel = nil
            self?.closeObserver = nil
            self?.objectWillChange.send()
        }

        panel = newPanel
        objectWillChange.send()
    }

    func close() {
        if let observer = closeObserver {
            NotificationCenter.default.removeObserver(observer)
            closeObserver = nil
        }
        panel?.close()
        panel = nil
        objectWillChange.send()
    }

    func toggle(report: Report, legalCase: LegalCase?) {
        if isOpen {
            close()
        } else {
            open(report: report, legalCase: legalCase)
        }
    }

    func updateContent(report: Report, legalCase: LegalCase?) {
        guard let panel else { return }
        let previewView = ReportPreviewView(report: report, legalCase: legalCase)
        let hostingView = NSHostingView(rootView: previewView)
        panel.contentView = hostingView
        panel.title = report.title.isEmpty ? "Report Preview" : "Preview \u{2014} \(report.title)"
    }
}

struct ReportEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var report: Report
    let legalCase: LegalCase?

    @StateObject private var previewPanel = PreviewPanelManager()
    @State private var showingBatesSettings = false
    @State private var showingICloudBrowser = false
    @State private var showingTemplateSave = false
    @State private var showingTemplateLoad = false
    @State private var copiedToClipboard = false

    var body: some View {
        VStack(spacing: 0) {
            editorPane
            statsBar
        }
        .onChange(of: report.modifiedAt) {
            if previewPanel.isOpen {
                previewPanel.updateContent(report: report, legalCase: legalCase)
            }
        }
        .onDisappear {
            previewPanel.close()
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    previewPanel.toggle(report: report, legalCase: legalCase)
                } label: {
                    Label("Preview", systemImage: previewPanel.isOpen ? "eye.fill" : "eye")
                }
                .help(previewPanel.isOpen ? "Close Preview Window" : "Open Preview Window")

                Button {
                    emailReport()
                } label: {
                    Label("Email", systemImage: "envelope")
                }

                Button {
                    copyToClipboard()
                } label: {
                    Label(copiedToClipboard ? "Copied" : "Copy", systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button {
                    showingICloudBrowser = true
                } label: {
                    Label("iCloud Drive", systemImage: "icloud")
                }

                Menu {
                    Button("Heading") { addSection(.heading) }
                    Button("Text") { addSection(.text) }
                    Button("Numbered List") { addSection(.numberedList) }
                    Button("Info Box") { addSection(.infoBox) }
                    Button("Checklist") { addSection(.checklist) }
                    Button("Table") { addSection(.table) }
                    Button("Block Quote") { addSection(.blockQuote) }
                    Divider()
                    Button("File / Photo") { addSection(.fileAttachment) }
                    Button("Separator") { addSection(.separator) }
                    Button("Signature Block") { addSection(.signature) }
                    Divider()
                    Button("Bates Numbering...") { showingBatesSettings.toggle() }
                    Divider()
                    Button("Load Template...") { showingTemplateLoad = true }
                } label: {
                    Label("Add", systemImage: "plus")
                }

                Button {
                    showingTemplateSave = true
                } label: {
                    Label("Save as Template", systemImage: "square.and.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showingBatesSettings) {
            BatesSettingsView(report: report)
        }
        .sheet(isPresented: $showingICloudBrowser) {
            ICloudDriveBrowser { url in addFileFromURL(url) }
        }
        .sheet(isPresented: $showingTemplateSave) {
            TemplateSaveSheet(report: report)
        }
        .sheet(isPresented: $showingTemplateLoad) {
            TemplateLoadSheet(report: report)
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 16) {
            Label("\(report.wordCount) words", systemImage: "text.word.spacing")
            Label("\(report.sections.count) sections", systemImage: "list.bullet")
            if report.attachmentCount > 0 {
                Label("\(report.attachmentCount) files", systemImage: "paperclip")
            }
            Spacer()
            if report.includeBatesNumbers {
                Label("Bates: \(report.batesNumber(for: 1))", systemImage: "number")
                    .foregroundStyle(.blue)
            }
            Text("Created \(report.createdAt.shortLegal)")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Editor Pane

    private var editorPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                reportHeader
                Divider()
                reportOptions
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sections")
                            .font(AppFonts.swiftUIHeading)
                        Spacer()
                        Text("\(report.sections.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(report.sortedSections) { section in
                        SectionEditor(section: section, onDelete: {
                            deleteSection(section)
                        }, onMoveUp: {
                            moveSection(section, direction: -1)
                        }, onMoveDown: {
                            moveSection(section, direction: 1)
                        })
                    }

                    // Quick-add bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            QuickAddButton(title: "Heading", icon: "textformat") { addSection(.heading) }
                            QuickAddButton(title: "Text", icon: "text.alignleft") { addSection(.text) }
                            QuickAddButton(title: "List", icon: "list.number") { addSection(.numberedList) }
                            QuickAddButton(title: "Info Box", icon: "rectangle.inset.filled") { addSection(.infoBox) }
                            QuickAddButton(title: "Checklist", icon: "checklist") { addSection(.checklist) }
                            QuickAddButton(title: "Table", icon: "tablecells") { addSection(.table) }
                            QuickAddButton(title: "Quote", icon: "text.quote") { addSection(.blockQuote) }
                            QuickAddButton(title: "File", icon: "photo") { addSection(.fileAttachment) }
                            QuickAddButton(title: "Separator", icon: "minus") { addSection(.separator) }
                            QuickAddButton(title: "Signature", icon: "signature") { addSection(.signature) }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(20)
        }
    }

    private var reportHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Report Title", text: Binding(
                get: { report.title },
                set: { report.title = $0; report.modifiedAt = .now }
            ))
            .font(AppFonts.swiftUITitle)
            .textFieldStyle(.plain)

            HStack {
                Text(report.context.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())

                if let legalCase {
                    Text(legalCase.displayTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Modified \(report.modifiedAt.shortLegal)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var reportOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 20) {
                Toggle("Header Info", isOn: Binding(
                    get: { report.includeHeader },
                    set: { report.includeHeader = $0; report.modifiedAt = .now }
                )).toggleStyle(.checkbox)

                Toggle("Page #", isOn: Binding(
                    get: { report.includePageNumbers },
                    set: { report.includePageNumbers = $0; report.modifiedAt = .now }
                )).toggleStyle(.checkbox)

                Toggle("Date", isOn: Binding(
                    get: { report.includeDate },
                    set: { report.includeDate = $0; report.modifiedAt = .now }
                )).toggleStyle(.checkbox)

                Toggle("Bates #", isOn: Binding(
                    get: { report.includeBatesNumbers },
                    set: { report.includeBatesNumbers = $0; report.modifiedAt = .now }
                )).toggleStyle(.checkbox)

                Spacer()

                HStack(spacing: 4) {
                    Text("By:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Name", text: Binding(
                        get: { report.preparedBy },
                        set: { report.preparedBy = $0; report.modifiedAt = .now }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .font(.caption)
                }
            }

            HStack(spacing: 4) {
                Text("Notice:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. CONFIDENTIAL", text: Binding(
                    get: { report.confidentialityNotice },
                    set: { report.confidentialityNotice = $0; report.modifiedAt = .now }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            }
        }
        .font(.caption)
    }

    // MARK: - Actions

    private func addSection(_ type: SectionType) {
        let section = ReportSection(order: report.sections.count, sectionType: type, content: "")
        if type == .fileAttachment {
            section.exhibitLabel = "Attachment \(report.sections.filter { $0.sectionType == .fileAttachment }.count + 1)"
        }
        section.report = report
        report.sections.append(section)
        report.modifiedAt = .now
    }

    private func addFileFromURL(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        let fileType = FileType.from(extension: url.pathExtension)
        let section = ReportSection(order: report.sections.count, sectionType: .fileAttachment, content: url.lastPathComponent)
        section.exhibitLabel = "Attachment \(report.sections.filter { $0.sectionType == .fileAttachment }.count + 1)"
        let attachment = FileAttachment(filename: url.lastPathComponent, fileType: fileType, fileData: data, originalPath: url.path)
        if fileType == .image, let image = NSImage(data: data) {
            let ratio = min(300 / image.size.width, 300 / image.size.height, 1.0)
            let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
            let thumb = NSImage(size: newSize)
            thumb.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
            thumb.unlockFocus()
            if let tiff = thumb.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                attachment.thumbnailData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
            }
        }
        attachment.section = section
        section.attachments.append(attachment)
        section.report = report
        report.sections.append(section)
        report.modifiedAt = .now
    }

    private func deleteSection(_ section: ReportSection) {
        report.sections.removeAll { $0.id == section.id }
        modelContext.delete(section)
        for (i, s) in report.sortedSections.enumerated() { s.order = i }
        report.modifiedAt = .now
    }

    private func moveSection(_ section: ReportSection, direction: Int) {
        let sorted = report.sortedSections
        guard let index = sorted.firstIndex(where: { $0.id == section.id }) else { return }
        let newIndex = index + direction
        guard newIndex >= 0, newIndex < sorted.count else { return }
        sorted[index].order = newIndex
        sorted[newIndex].order = index
        report.modifiedAt = .now
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(report.plainTextExport, forType: .string)
        copiedToClipboard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedToClipboard = false }
    }

    private func emailReport() {
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

// MARK: - Section Editor

struct SectionEditor: View {
    @Bindable var section: ReportSection
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: section.sectionType.icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(section.sectionType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let label = section.exhibitLabel {
                    Text("(\(label))")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                Spacer()
                Button(action: onMoveUp) { Image(systemName: "chevron.up") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Button(action: onMoveDown) { Image(systemName: "chevron.down") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Button(action: onDelete) { Image(systemName: "trash") }
                    .buttonStyle(.plain).foregroundStyle(.red.opacity(0.7))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Group {
                switch section.sectionType {
                case .heading:
                    TextField("Heading text", text: $section.content)
                        .font(.system(size: 14, weight: .semibold))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)

                case .text:
                    TextEditor(text: $section.content)
                        .font(.system(size: 13))
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)

                case .numberedList:
                    VStack(alignment: .leading, spacing: 2) {
                        Text("One item per line \u{2014} they\u{2019}ll be auto-numbered")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                        TextEditor(text: $section.content)
                            .font(.system(size: 13))
                            .frame(minHeight: 60)
                            .scrollContentBackground(.hidden)
                    }

                case .infoBox:
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Key details \u{2014} appears in a bordered box when printed")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                        TextEditor(text: $section.content)
                            .font(.system(size: 13))
                            .frame(minHeight: 60)
                            .scrollContentBackground(.hidden)
                    }

                case .fileAttachment:
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Label:")
                                .font(.caption)
                            TextField("Label", text: Binding(
                                get: { section.exhibitLabel ?? "" },
                                set: { section.exhibitLabel = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                            .font(.caption)
                        }
                        AttachmentManagerView(section: section)
                        TextField("Description / notes", text: $section.content, axis: .vertical)
                            .font(.system(size: 12))
                            .lineLimit(2...4)
                    }
                    .padding(.horizontal, 8)

                case .separator:
                    Divider()
                        .padding(.horizontal, 8)

                case .signature:
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name for signature line:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Name", text: $section.content)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal, 8)

                case .checklist:
                    ChecklistEditor(section: section)
                        .padding(.horizontal, 8)

                case .table:
                    TableSectionEditor(section: section)
                        .padding(.horizontal, 8)

                case .blockQuote:
                    BlockQuoteEditor(section: section)
                        .padding(.horizontal, 8)
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator, lineWidth: 0.5))
    }
}

// MARK: - Checklist Editor

struct ChecklistEditor: View {
    @Bindable var section: ReportSection

    private var items: [(checked: Bool, text: String)] {
        let lines = section.content.components(separatedBy: "\n")
        return lines.compactMap { line in
            if line.isEmpty { return nil }
            if line.hasPrefix("[x] ") {
                return (true, String(line.dropFirst(4)))
            } else if line.hasPrefix("[ ] ") {
                return (false, String(line.dropFirst(4)))
            } else {
                return (false, line)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Check items off as they are completed")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                HStack(spacing: 6) {
                    Toggle("", isOn: Binding(
                        get: { item.checked },
                        set: { newValue in
                            updateItem(at: idx, checked: newValue, text: item.text)
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                    TextField("Item", text: Binding(
                        get: { item.text },
                        set: { newValue in
                            updateItem(at: idx, checked: item.checked, text: newValue)
                        }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .strikethrough(item.checked, color: .secondary)
                    .foregroundStyle(item.checked ? .secondary : .primary)

                    Button {
                        removeItem(at: idx)
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.red.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                appendItem()
            } label: {
                Label("Add Item", systemImage: "plus.circle")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
    }

    private func rebuildContent(from list: [(checked: Bool, text: String)]) {
        section.content = list.map { item in
            "\(item.checked ? "[x] " : "[ ] ")\(item.text)"
        }.joined(separator: "\n")
        section.lastEditedAt = .now
    }

    private func updateItem(at index: Int, checked: Bool, text: String) {
        var list = items
        guard index < list.count else { return }
        list[index] = (checked: checked, text: text)
        rebuildContent(from: list)
    }

    private func removeItem(at index: Int) {
        var list = items
        guard index < list.count else { return }
        list.remove(at: index)
        rebuildContent(from: list)
    }

    private func appendItem() {
        var list = items
        list.append((checked: false, text: ""))
        rebuildContent(from: list)
    }
}

// MARK: - Table Section Editor

struct TableSectionEditor: View {
    @Bindable var section: ReportSection

    private var rows: [(key: String, value: String)] {
        let lines = section.content.components(separatedBy: "\n")
        return lines.compactMap { line in
            if line.isEmpty { return nil }
            let parts = line.components(separatedBy: "\t")
            if parts.count >= 2 {
                return (key: parts[0], value: parts.dropFirst().joined(separator: "\t"))
            } else {
                return (key: parts[0], value: "")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Key-value pairs \u{2014} rendered as a two-column table")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                Text("Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 160, alignment: .leading)
                Text("Value")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack(spacing: 8) {
                    TextField("Key", text: Binding(
                        get: { row.key },
                        set: { newKey in updateRow(at: idx, key: newKey, value: row.value) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .frame(width: 160)

                    TextField("Value", text: Binding(
                        get: { row.value },
                        set: { newValue in updateRow(at: idx, key: row.key, value: newValue) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                    Button {
                        removeRow(at: idx)
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.red.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                appendRow()
            } label: {
                Label("Add Row", systemImage: "plus.circle")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
    }

    private func rebuildContent(from list: [(key: String, value: String)]) {
        section.content = list.map { "\($0.key)\t\($0.value)" }.joined(separator: "\n")
        section.lastEditedAt = .now
    }

    private func updateRow(at index: Int, key: String, value: String) {
        var list = rows
        guard index < list.count else { return }
        list[index] = (key: key, value: value)
        rebuildContent(from: list)
    }

    private func removeRow(at index: Int) {
        var list = rows
        guard index < list.count else { return }
        list.remove(at: index)
        rebuildContent(from: list)
    }

    private func appendRow() {
        var list = rows
        list.append((key: "", value: ""))
        rebuildContent(from: list)
    }
}

// MARK: - Block Quote Editor

struct BlockQuoteEditor: View {
    @Bindable var section: ReportSection

    private var quoteText: String {
        let lines = section.content.components(separatedBy: "\n")
        // Only strip the last line if it is the attribution line
        if let last = lines.last, last.hasPrefix("-- ") {
            return lines.dropLast().joined(separator: "\n")
        }
        return section.content
    }

    private var attribution: String {
        let lines = section.content.components(separatedBy: "\n")
        if let last = lines.last, last.hasPrefix("-- ") {
            return String(last.dropFirst(3))
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quote or testimony \u{2014} styled with a left accent border")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 4)

                TextEditor(text: Binding(
                    get: { quoteText },
                    set: { newText in
                        rebuildContent(quote: newText, attrib: attribution)
                    }
                ))
                .font(.system(size: 13))
                .italic()
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
                .padding(.leading, 8)
            }
            .padding(4)
            .background(Color.blue.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack(spacing: 4) {
                Text("Attribution:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. witness name, source", text: Binding(
                    get: { attribution },
                    set: { newAttrib in
                        rebuildContent(quote: quoteText, attrib: newAttrib)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
            }
        }
    }

    private func rebuildContent(quote: String, attrib: String) {
        if attrib.isEmpty {
            section.content = quote
        } else {
            section.content = quote + "\n-- " + attrib
        }
        section.lastEditedAt = .now
    }
}

// MARK: - Bates Settings

struct BatesSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var report: Report

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Bates Numbering")
                    .font(AppFonts.swiftUITitle)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding()
            Divider()
            Form {
                Section("Configuration") {
                    Toggle("Enable Bates Numbers", isOn: $report.includeBatesNumbers)
                    TextField("Prefix (e.g. DEF, PLT)", text: $report.batesPrefix)
                    Stepper("Start: \(report.batesStartNumber)", value: $report.batesStartNumber, in: 1...999999)
                }
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Page 1: \(report.batesNumber(for: 1))")
                        Text("Page 2: \(report.batesNumber(for: 2))")
                        Text("Page 3: \(report.batesNumber(for: 3))")
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 400, height: 320)
    }
}

// MARK: - Template Save Sheet

struct TemplateSaveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let report: Report

    @State private var templateName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Save as Template")
                    .font(AppFonts.swiftUITitle)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Save the current section layout as a reusable template.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Template Name", text: $templateName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Context: \(report.context.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(report.sections.count) sections")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Button("Save Template") {
                        let template = ReportTemplate(
                            name: templateName.isEmpty ? "Untitled Template" : templateName,
                            context: report.context,
                            sections: report.templateSections
                        )
                        modelContext.insert(template)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
        }
        .frame(width: 400, height: 240)
    }
}

// MARK: - Template Load Sheet

struct TemplateLoadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let report: Report

    @Query(sort: \ReportTemplate.createdAt, order: .reverse) private var templates: [ReportTemplate]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Load Template")
                    .font(AppFonts.swiftUITitle)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()

            if templates.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No templates saved yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Use \u{201C}Save as Template\u{201D} to create reusable layouts.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(templates) { template in
                        Button {
                            applyTemplate(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.system(size: 13, weight: .medium))
                                HStack(spacing: 12) {
                                    Text(template.context.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                    Text("\(template.sections.count) sections")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(template.createdAt.shortLegal)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            modelContext.delete(templates[i])
                        }
                    }
                }
            }
        }
        .frame(width: 450, height: 350)
    }

    private func applyTemplate(_ template: ReportTemplate) {
        // Delete old sections from model context before replacing
        for section in report.sections {
            modelContext.delete(section)
        }
        report.applySections(from: template.sections)
        report.modifiedAt = .now
        dismiss()
    }
}

// MARK: - Quick Add Button

struct QuickAddButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
