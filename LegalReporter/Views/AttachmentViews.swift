import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Attachment Manager (for a section)

struct AttachmentManagerView: View {
    @Environment(\.modelContext) private var modelContext
    let section: ReportSection

    @State private var showingFilePicker = false
    @State private var showingICloudBrowser = false
    @State private var selectedAttachment: FileAttachment?
    @State private var dragOver = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Attachments list
            if !section.attachments.isEmpty {
                ForEach(section.attachments.sorted(by: { $0.addedAt < $1.addedAt })) { attachment in
                    AttachmentRow(attachment: attachment) {
                        removeAttachment(attachment)
                    }
                }
            }

            // Add buttons
            HStack(spacing: 8) {
                Button {
                    showingFilePicker = true
                } label: {
                    Label("Add File", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showingICloudBrowser = true
                } label: {
                    Label("iCloud Drive", systemImage: "icloud")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste Image", systemImage: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Drop zone
            if section.attachments.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                    .foregroundStyle(dragOver ? .blue : .secondary.opacity(0.4))
                    .frame(height: 60)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.down.doc")
                                .foregroundStyle(.secondary)
                            Text("Drop files here")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDrop(of: [UTType.fileURL], isTargeted: $dragOver) { providers in
                        handleDrop(providers)
                        return true
                    }
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            FilePickerSheet { url in
                addFile(from: url)
            }
        }
        .sheet(isPresented: $showingICloudBrowser) {
            ICloudDriveBrowser { url in
                addFile(from: url)
            }
        }
    }

    private func addFile(from url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }

        let ext = url.pathExtension
        let fileType = FileType.from(extension: ext)

        let attachment = FileAttachment(
            filename: url.lastPathComponent,
            fileType: fileType,
            fileData: data,
            originalPath: url.path
        )

        // Generate thumbnail for images
        if fileType == .image, let image = NSImage(data: data) {
            attachment.thumbnailData = generateThumbnail(from: image)
        }

        attachment.section = section
        section.attachments.append(attachment)
        section.lastEditedAt = .now
    }

    private func removeAttachment(_ attachment: FileAttachment) {
        section.attachments.removeAll { $0.id == attachment.id }
        modelContext.delete(attachment)
        section.lastEditedAt = .now
    }

    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general

        // Try image first
        if let image = NSImage(pasteboard: pasteboard),
           let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            let attachment = FileAttachment(
                filename: "Pasted Image \(Date.now.shortLegal).png",
                fileType: .image,
                fileData: pngData
            )
            attachment.thumbnailData = generateThumbnail(from: image)
            attachment.section = section
            section.attachments.append(attachment)
            section.lastEditedAt = .now
            return
        }

        // Try file URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first {
            addFile(from: url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    addFile(from: url)
                }
            }
        }
    }

    private func generateThumbnail(from image: NSImage, maxSize: CGFloat = 300) -> Data? {
        let ratio = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let newSize = NSSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        thumbnail.unlockFocus()

        guard let tiff = thumbnail.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }
}

// MARK: - Attachment Row

struct AttachmentRow: View {
    let attachment: FileAttachment
    let onRemove: () -> Void

    @State private var showingDetail = false

    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail or icon
            if attachment.isImage, let thumbData = attachment.thumbnailData, let image = NSImage(data: thumbData) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: attachment.fileType.icon)
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.filename)
                    .font(.caption)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(attachment.fileType.rawValue)
                    Text(attachment.formattedSize)
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                showingDetail = true
            } label: {
                Image(systemName: "eye")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button {
                exportAttachment()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red.opacity(0.6))
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .sheet(isPresented: $showingDetail) {
            AttachmentDetailView(attachment: attachment)
        }
    }

    private func exportAttachment() {
        guard let data = attachment.fileData else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = attachment.filename
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

// MARK: - Attachment Detail View (full preview)

struct AttachmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let attachment: FileAttachment

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(attachment.filename)
                    .font(AppFonts.swiftUITitle)
                Spacer()
                Text(attachment.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Close") { dismiss() }
            }
            .padding()

            Divider()

            if attachment.isImage, let data = attachment.fileData, let image = NSImage(data: data) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 800, maxHeight: 800)
                        .padding()
                }
            } else if attachment.fileType == .pdf {
                VStack(spacing: 8) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("PDF Document")
                        .font(.body)
                    Text(attachment.filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open in Preview") {
                        openInDefaultApp()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: attachment.fileType.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(attachment.filename)
                        .font(.body)
                    Text(attachment.fileType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open in Default App") {
                        openInDefaultApp()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Text("Added: \(attachment.addedAt.timestampFormatted)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if !attachment.originalPath.isEmpty {
                    Text("From: \(attachment.originalPath)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(8)
            .background(.bar)
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    private func openInDefaultApp() {
        guard let data = attachment.fileData else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(attachment.filename)
        do {
            try data.write(to: tempURL)
            NSWorkspace.shared.open(tempURL)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could Not Open File"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

// MARK: - File Picker Sheet (wraps NSOpenPanel)

struct FilePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (URL) -> Void

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = [
                    .image, .pdf, .plainText, .rtf, .data,
                    .jpeg, .png, .heic, .tiff, .gif
                ]
                panel.message = "Select a file to attach"

                if panel.runModal() == .OK, let url = panel.url {
                    onPick(url)
                }
                dismiss()
            }
    }
}

// MARK: - Case Files View (case-level attachment management)

struct CaseFilesView: View {
    @Environment(\.modelContext) private var modelContext
    let legalCase: LegalCase

    @State private var showingFilePicker = false
    @State private var showingICloudBrowser = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Case Files")
                    .font(AppFonts.swiftUIHeading)
                Spacer()
                Text("\(legalCase.files.count) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Menu {
                    Button("Add from Computer...") { showingFilePicker = true }
                    Button("Add from iCloud Drive...") { showingICloudBrowser = true }
                } label: {
                    Label("Add File", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
            }

            if legalCase.files.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No files attached to this case")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Add photos, PDFs, documents, or any other files from your computer or iCloud Drive")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 120, maximum: 160))
                ], spacing: 12) {
                    ForEach(legalCase.files.sorted(by: { $0.addedAt > $1.addedAt })) { file in
                        CaseFileCard(attachment: file) {
                            legalCase.files.removeAll { $0.id == file.id }
                            modelContext.delete(file)
                            legalCase.modifiedAt = .now
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            FilePickerSheet { url in addFile(from: url) }
        }
        .sheet(isPresented: $showingICloudBrowser) {
            ICloudDriveBrowser { url in addFile(from: url) }
        }
    }

    private func addFile(from url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        let fileType = FileType.from(extension: url.pathExtension)

        let attachment = FileAttachment(
            filename: url.lastPathComponent,
            fileType: fileType,
            fileData: data,
            originalPath: url.path
        )

        if fileType == .image, let image = NSImage(data: data) {
            attachment.thumbnailData = generateThumbnail(from: image)
        }

        attachment.legalCase = legalCase
        legalCase.files.append(attachment)
        legalCase.modifiedAt = .now
    }

    private func generateThumbnail(from image: NSImage, maxSize: CGFloat = 200) -> Data? {
        let ratio = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
        thumbnail.unlockFocus()
        guard let tiff = thumbnail.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }
}

struct CaseFileCard: View {
    let attachment: FileAttachment
    let onRemove: () -> Void

    @State private var showingDetail = false

    var body: some View {
        VStack(spacing: 6) {
            if attachment.isImage, let data = attachment.thumbnailData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: attachment.fileType.icon)
                    .font(.title)
                    .frame(width: 100, height: 70)
                    .foregroundStyle(.secondary)
            }

            Text(attachment.filename)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(attachment.formattedSize)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 0.5)
        )
        .contextMenu {
            Button("View") { showingDetail = true }
            Button("Remove", role: .destructive, action: onRemove)
        }
        .onTapGesture(count: 2) { showingDetail = true }
        .sheet(isPresented: $showingDetail) {
            AttachmentDetailView(attachment: attachment)
        }
    }
}
