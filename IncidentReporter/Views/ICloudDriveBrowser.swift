import SwiftUI
import AppKit

// MARK: - iCloud Drive Item

struct ICloudItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let fileSize: Int64
    let modifiedDate: Date?
    let fileType: FileType

    var icon: String {
        isDirectory ? "folder.fill" : fileType.icon
    }

    var formattedSize: String {
        guard !isDirectory else { return "" }
        let bytes = Double(fileSize)
        if bytes < 1024 { return "\(fileSize) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", bytes / 1024) }
        return String(format: "%.1f MB", bytes / (1024 * 1024))
    }
}

// MARK: - iCloud Drive Browser

struct ICloudDriveBrowser: View {
    @Environment(\.dismiss) private var dismiss
    let onPickFile: (URL) -> Void

    @State private var currentPath: URL = iCloudDriveURL
    @State private var items: [ICloudItem] = []
    @State private var pathHistory: [URL] = []
    @State private var selectedItem: ICloudItem?
    @State private var previewImage: NSImage?
    @State private var errorMessage: String?
    @State private var searchText = ""

    private static var iCloudDriveURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
    }

    var filteredItems: [ICloudItem] {
        if searchText.isEmpty { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundStyle(.blue)
                Text("iCloud Drive")
                    .font(AppFonts.swiftUITitle)
                Spacer()

                Button("Open from Finder...") {
                    openFilePicker()
                }

                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Breadcrumb navigation
            HStack {
                Button {
                    if !pathHistory.isEmpty {
                        currentPath = pathHistory.removeLast()
                        loadItems()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(pathHistory.isEmpty)

                Button {
                    pathHistory.removeAll()
                    currentPath = Self.iCloudDriveURL
                    loadItems()
                } label: {
                    Image(systemName: "icloud")
                }

                Text(currentPath.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 150)
                }
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Content
            HSplitView {
                // File list
                if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.icloud")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text("Make sure you're signed into iCloud in System Settings.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredItems, selection: $selectedItem) { item in
                        ICloudItemRow(item: item)
                            .tag(item)
                            .onTapGesture(count: 2) {
                                if item.isDirectory {
                                    navigateTo(item.url)
                                } else {
                                    onPickFile(item.url)
                                    dismiss()
                                }
                            }
                            .onTapGesture(count: 1) {
                                selectedItem = item
                                if item.fileType == .image {
                                    loadPreview(for: item)
                                } else {
                                    previewImage = nil
                                }
                            }
                    }
                    .listStyle(.plain)
                    .frame(minWidth: 350)
                }

                // Preview pane
                VStack {
                    if let item = selectedItem {
                        VStack(spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.system(size: 40))
                                .foregroundStyle(item.isDirectory ? .blue : .secondary)

                            if let preview = previewImage {
                                Image(nsImage: preview)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 300, maxHeight: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(radius: 2)
                            }

                            Text(item.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)

                            if !item.isDirectory {
                                Text(item.formattedSize)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let mod = item.modifiedDate {
                                    Text("Modified: \(mod.shortFormatted)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Button("Add to Report") {
                                    onPickFile(item.url)
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .padding(.top, 8)
                            } else {
                                Button("Open Folder") {
                                    navigateTo(item.url)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.viewfinder")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("Select a file to preview")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 250)
            }
        }
        .frame(minWidth: 800, minHeight: 550)
        .onAppear { loadItems() }
    }

    // MARK: - Navigation

    private func navigateTo(_ url: URL) {
        pathHistory.append(currentPath)
        currentPath = url
        selectedItem = nil
        previewImage = nil
        searchText = ""
        loadItems()
    }

    private func loadItems() {
        errorMessage = nil
        let fm = FileManager.default

        guard fm.fileExists(atPath: currentPath.path) else {
            errorMessage = "iCloud Drive folder not found.\nPath: \(currentPath.path)"
            items = []
            return
        }

        do {
            let contents = try fm.contentsOfDirectory(
                at: currentPath,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            items = contents.compactMap { url in
                let resources = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                let isDir = resources?.isDirectory ?? false
                let size = Int64(resources?.fileSize ?? 0)
                let modified = resources?.contentModificationDate

                return ICloudItem(
                    url: url,
                    name: url.lastPathComponent,
                    isDirectory: isDir,
                    fileSize: size,
                    modifiedDate: modified,
                    fileType: isDir ? .other : FileType.from(extension: url.pathExtension)
                )
            }
            .sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        } catch {
            errorMessage = "Could not read iCloud Drive: \(error.localizedDescription)"
            items = []
        }
    }

    private func loadPreview(for item: ICloudItem) {
        guard item.fileType == .image else { previewImage = nil; return }
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOf: item.url) {
                DispatchQueue.main.async {
                    previewImage = image
                }
            }
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .pdf, .plainText, .rtf, .data]
        panel.message = "Select a file to add to your report"

        if panel.runModal() == .OK, let url = panel.url {
            onPickFile(url)
            dismiss()
        }
    }
}

// MARK: - Item Row

struct ICloudItemRow: View {
    let item: ICloudItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .foregroundStyle(item.isDirectory ? .blue : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)

                if !item.isDirectory {
                    HStack(spacing: 8) {
                        Text(item.fileType.rawValue)
                        Text(item.formattedSize)
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let date = item.modifiedDate, !item.isDirectory {
                Text(date.shortFormatted)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}
