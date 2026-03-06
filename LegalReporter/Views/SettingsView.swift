import SwiftUI
import SwiftData
import Sparkle

struct SettingsView: View {
    @ObservedObject var updaterViewModel: UpdaterViewModel

    @AppStorage("defaultPreparedBy") private var defaultPreparedBy = ""
    @AppStorage("defaultIncludeHeader") private var defaultIncludeHeader = true
    @AppStorage("defaultIncludePageNumbers") private var defaultIncludePageNumbers = true
    @AppStorage("defaultIncludeDate") private var defaultIncludeDate = true

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gear") }

            reportDefaultsSettings
                .tabItem { Label("Report Defaults", systemImage: "doc.text") }

            headerLayoutSettings
                .tabItem { Label("Header & Layout", systemImage: "rectangle.topthird.inset.filled") }

            namingSettings
                .tabItem { Label("Naming", systemImage: "number") }

            printSettings
                .tabItem { Label("Printing", systemImage: "printer") }

            TagsSettingsView()
                .tabItem { Label("Tags", systemImage: "tag") }

            updatesSettings
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(width: 540, height: 480)
    }

    // MARK: - Updates Tab

    private var updatesSettings: some View {
        Form {
            Section("Software Updates") {
                HStack {
                    Text("Current Version")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1")
                        .foregroundStyle(.secondary)
                }

                Button("Check for Updates...") {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            }

            Section("Preferences") {
                Toggle("Automatically check for updates",
                       isOn: Binding(
                        get: { updaterViewModel.updaterController.updater.automaticallyChecksForUpdates },
                        set: { updaterViewModel.updaterController.updater.automaticallyChecksForUpdates = $0 }
                       ))

                Toggle("Automatically download updates",
                       isOn: Binding(
                        get: { updaterViewModel.updaterController.updater.automaticallyDownloadsUpdates },
                        set: { updaterViewModel.updaterController.updater.automaticallyDownloadsUpdates = $0 }
                       ))
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - General Tab

    private var generalSettings: some View {
        Form {
            Section("Defaults") {
                TextField("Default 'Prepared By' Name", text: $defaultPreparedBy)
                Toggle("Include header info by default", isOn: $defaultIncludeHeader)
                Toggle("Include page numbers by default", isOn: $defaultIncludePageNumbers)
                Toggle("Include date by default", isOn: $defaultIncludeDate)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Report Defaults Tab

    private var reportDefaultsSettings: some View {
        ReportDefaultsSettingsTab()
    }

    // MARK: - Header & Layout Tab

    private var headerLayoutSettings: some View {
        HeaderLayoutSettingsTab()
    }

    // MARK: - Naming Tab

    private var namingSettings: some View {
        NamingSettingsTab()
    }

    // MARK: - Printing Tab

    private var printSettings: some View {
        Form {
            Section("Page Layout") {
                HStack {
                    Text("Paper Size:")
                    Spacer()
                    Text("US Letter (8.5\" x 11\")")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Margins:")
                    Spacer()
                    Text("1 inch (all sides)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Font:")
                    Spacer()
                    Text("San Francisco (SF Pro)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Shortcuts") {
                HStack {
                    Text("Print")
                    Spacer()
                    Text("Cmd + P").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                HStack {
                    Text("Export PDF")
                    Spacer()
                    Text("Cmd + Shift + E").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                HStack {
                    Text("Email Report")
                    Spacer()
                    Text("Cmd + Shift + M").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                HStack {
                    Text("Copy as Text")
                    Spacer()
                    Text("Cmd + Shift + C").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Report Defaults Settings Tab

struct ReportDefaultsSettingsTab: View {
    @AppStorage("defaultTitleFormat") private var defaultTitleFormat = "{type} - {date}"
    @AppStorage("defaultConfidentialityNotice") private var defaultConfidentialityNotice = ""
    @AppStorage("defaultBatesPrefix") private var defaultBatesPrefix = ""
    @AppStorage("autoNumberReports") private var autoNumberReports = false
    @AppStorage("autoNumberCounter") private var autoNumberCounter = 0

    var body: some View {
        Form {
            Section("Title Format") {
                TextField("Default title pattern", text: $defaultTitleFormat)
                Text("Available tokens: {type}, {date}, {case}")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Auto-number reports", isOn: $autoNumberReports)
                if autoNumberReports {
                    HStack {
                        Text("Next number:")
                            .foregroundStyle(.secondary)
                        Stepper("\(autoNumberCounter + 1)", value: $autoNumberCounter, in: 0...99999)
                    }
                    Text("Titles will include \"Report #N\" automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Default Notices") {
                TextField("Default confidentiality notice", text: $defaultConfidentialityNotice)
                    .lineLimit(1...3)
                Text("e.g. CONFIDENTIAL - ATTORNEY WORK PRODUCT")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Bates Numbering") {
                TextField("Default Bates prefix", text: $defaultBatesPrefix)
                Text("e.g. DEF, PLT, EXH")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Preview") {
                let sampleTitle = buildSampleTitle()
                HStack {
                    Text("Sample title:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(sampleTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func buildSampleTitle() -> String {
        var title = defaultTitleFormat
        title = title.replacingOccurrences(of: "{type}", with: "Legal")
        title = title.replacingOccurrences(of: "{date}", with: Date.now.shortLegal)
        title = title.replacingOccurrences(of: "{case}", with: "Sample Case")
        if autoNumberReports {
            title += " Report #\(autoNumberCounter + 1)"
        }
        return title
    }
}

// MARK: - Header & Layout Settings Tab

struct HeaderLayoutSettingsTab: View {
    @AppStorage("firmName") private var firmName = ""
    @AppStorage("firmAddress") private var firmAddress = ""
    @AppStorage("headerAlignment") private var headerAlignment = "left"
    @AppStorage("showFirmNameInHeader") private var showFirmNameInHeader = true
    @AppStorage("showFirmAddressInHeader") private var showFirmAddressInHeader = true
    @AppStorage("headerSeparatorStyle") private var headerSeparatorStyle = "line"
    @AppStorage("customFooterText") private var customFooterText = ""
    @AppStorage("customWatermarkText") private var customWatermarkText = ""

    var body: some View {
        Form {
            Section("Firm Information") {
                TextField("Company / Firm name", text: $firmName)
                TextField("Address", text: $firmAddress)
                    .lineLimit(1...3)
            }

            Section("Header Display") {
                Toggle("Show firm name in header", isOn: $showFirmNameInHeader)
                Toggle("Show firm address in header", isOn: $showFirmAddressInHeader)

                Picker("Header alignment", selection: $headerAlignment) {
                    Text("Left").tag("left")
                    Text("Center").tag("center")
                    Text("Right").tag("right")
                }
                .pickerStyle(.segmented)

                Picker("Header separator", selection: $headerSeparatorStyle) {
                    Text("Line").tag("line")
                    Text("Double Line").tag("doubleLine")
                    Text("None").tag("none")
                }
            }

            Section("Footer") {
                TextField("Custom footer text", text: $customFooterText)
                Text("Shown at the bottom of each page.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Watermark") {
                TextField("Watermark text", text: $customWatermarkText)
                Text("e.g. DRAFT, CONFIDENTIAL. Displayed diagonally across each page.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Naming Settings Tab

struct NamingSettingsTab: View {
    @AppStorage("caseNumberPrefix") private var caseNumberPrefix = ""
    @AppStorage("autoGenerateReferenceNumbers") private var autoGenerateReferenceNumbers = false
    @AppStorage("referenceNumberFormat") private var referenceNumberFormat = "sequential"
    @AppStorage("referenceNumberSequentialCounter") private var referenceNumberSequentialCounter = 0
    @AppStorage("defaultCaseType") private var defaultCaseType = "General"

    var body: some View {
        Form {
            Section("Case Number Prefix") {
                TextField("Prefix", text: $caseNumberPrefix)
                Text("e.g. CASE-, REF-, LR-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Reference Numbers") {
                Toggle("Auto-generate reference numbers", isOn: $autoGenerateReferenceNumbers)

                if autoGenerateReferenceNumbers {
                    Picker("Format", selection: $referenceNumberFormat) {
                        Text("Sequential (001, 002, ...)").tag("sequential")
                        Text("Date-based (2024-001)").tag("dateBased")
                        Text("Custom prefix + sequential").tag("custom")
                    }

                    if referenceNumberFormat == "sequential" || referenceNumberFormat == "custom" {
                        HStack {
                            Text("Next number:")
                                .foregroundStyle(.secondary)
                            Stepper("\(referenceNumberSequentialCounter + 1)", value: $referenceNumberSequentialCounter, in: 0...99999)
                        }
                    }

                    HStack {
                        Text("Preview:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(previewReferenceNumber())
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                }
            }

            Section("Default Case Type") {
                Picker("Default type for new cases", selection: $defaultCaseType) {
                    ForEach(ReportContext.allCases) { ctx in
                        Text(ctx.rawValue).tag(ctx.rawValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func previewReferenceNumber() -> String {
        let nextNum = referenceNumberSequentialCounter + 1
        let prefix = caseNumberPrefix

        switch referenceNumberFormat {
        case "sequential":
            return "\(prefix)\(String(format: "%03d", nextNum))"
        case "dateBased":
            let year = Calendar.current.component(.year, from: Date.now)
            return "\(prefix)\(year)-\(String(format: "%03d", nextNum))"
        case "custom":
            return "\(prefix)\(String(format: "%03d", nextNum))"
        default:
            return "\(prefix)\(String(format: "%03d", nextNum))"
        }
    }
}

// MARK: - Tags Settings Tab

struct TagsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var newTagName = ""
    @State private var newTagColor: TagColor = .blue
    @State private var editingTagID: PersistentIdentifier?
    @State private var editingName = ""

    var body: some View {
        VStack(spacing: 0) {
            // Add tag controls
            HStack(spacing: 8) {
                TextField("New tag name", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .onSubmit { addTag() }

                Picker("Color", selection: $newTagColor) {
                    ForEach(TagColor.allCases) { color in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color.color)
                                .frame(width: 8, height: 8)
                            Text(color.rawValue.capitalized)
                        }
                        .tag(color)
                    }
                }
                .frame(width: 120)

                Button(action: addTag) {
                    Label("Add Tag", systemImage: "plus")
                }
                .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            Divider()

            // Tags list
            if tags.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "tag.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No tags yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Add a tag above to get started.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                List {
                    ForEach(tags) { tag in
                        tagRow(tag)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    deleteTag(tag)
                                }
                            }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - Tag Row

    @ViewBuilder
    private func tagRow(_ tag: Tag) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tag.color)
                .frame(width: 10, height: 10)

            if editingTagID == tag.persistentModelID {
                TextField("Tag name", text: $editingName, onCommit: {
                    commitEdit(tag)
                })
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)
                .onExitCommand { cancelEdit() }
            } else {
                Text(tag.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            // Case count
            let count = tag.cases.count
            Text("\(count) \(count == 1 ? "case" : "cases")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            // Edit button
            if editingTagID == tag.persistentModelID {
                Button {
                    commitEdit(tag)
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    startEditing(tag)
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Delete button
            Button(role: .destructive) {
                deleteTag(tag)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func addTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let tag = Tag(name: trimmed, colorHex: newTagColor.hex)
        modelContext.insert(tag)
        newTagName = ""
    }

    private func deleteTag(_ tag: Tag) {
        if editingTagID == tag.persistentModelID {
            cancelEdit()
        }
        modelContext.delete(tag)
    }

    private func startEditing(_ tag: Tag) {
        editingTagID = tag.persistentModelID
        editingName = tag.name
    }

    private func commitEdit(_ tag: Tag) {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            tag.name = trimmed
        }
        cancelEdit()
    }

    private func cancelEdit() {
        editingTagID = nil
        editingName = ""
    }
}
