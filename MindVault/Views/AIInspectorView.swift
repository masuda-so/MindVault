import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct AIInspectorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AIJobQueue.self) private var aiQueue

    @Bindable var note: Note
    let allNotes: [Note]
    let entitlement: SubscriptionEntitlement?

    @State private var isExporting = false
    @State private var exportDocument = MindVaultExportDocument()
    @State private var exportContentType: UTType = .plainText
    @State private var exportFilename = "MindVaultExport.md"
    @State private var isImporting = false
    @State private var importErrorMessage: String?
    @State private var batchOrganizationMessage: String?

    var relatedNotes: [Note] {
        let ids = Set(note.aiMetadata?.relatedNoteIDs ?? [])
        return allNotes.filter { ids.contains($0.id) }
    }

    var unorganizedNotes: [Note] {
        allNotes
            .filter { note in
                note.collectionName == "Unorganized"
                    || note.collectionName == "未整理"
                    || note.tags.contains("Unorganized")
                    || note.tags.contains("未整理")
                    || note.title.localizedStandardContains("Untitled")
                    || note.title.localizedStandardContains("Scratch")
                    || note.title.localizedStandardContains("無題")
                    || note.title.localizedStandardContains("雑メモ")
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                aiStatusPanel
                privacyPanel
                unorganizedPanel
                suggestionPanel
                relatedPanel
                importExportPanel
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(
            minWidth: horizontalSizeClass == .compact ? 0 : 280,
            idealWidth: horizontalSizeClass == .compact ? nil : 320,
            maxWidth: horizontalSizeClass == .compact ? .infinity : 360,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(AIInspectorStyle.background.ignoresSafeArea())
        .navigationTitle("AI Suggestions")
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportFilename
        ) { _ in }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.plainText, .json, .commaSeparatedText]) { result in
            importFile(result)
        }
    }

    private var aiStatusPanel: some View {
        VaultPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("AI Assistant", systemImage: "sparkles")
                        .font(.headline)
                    Spacer()
                    Circle()
                        .fill(aiQueue.availability.isAvailable ? Color.mint : Color.orange)
                        .frame(width: 9, height: 9)
                }
                Text(aiQueue.availability.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    aiQueue.refreshAvailability()
                    aiQueue.enqueueOrganization(note: note, allNotes: allNotes, entitlement: entitlement, context: modelContext)
                } label: {
                    Label("Run AI Organization", systemImage: "wand.and.sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .disabled(!note.isAIEligible || !aiQueue.availability.isAvailable)
                .accessibilityIdentifier("runAIOrganizationButton")
            }
        }
    }

    private var privacyPanel: some View {
        VaultPanel {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Include this note in AI processing", isOn: $note.isAIEligible)
                    .font(.subheadline.weight(.semibold))
                Text(note.isAIEligible ? "Processed only with on-device Foundation Models. Nothing is sent externally." : "This note is excluded from AI organization, embeddings, and AI chat search.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var suggestionPanel: some View {
        VaultPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Organization Draft")
                        .font(.headline)
                    Spacer()
                    Text(note.aiMetadata?.suggestionStatus ?? "draft")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let metadata = note.aiMetadata, hasSuggestion(metadata) {
                    if metadata.suggestionStatus == "editing" {
                        editableSuggestionFields(metadata)
                    } else {
                        suggestionRow(title: String(localized: "Title"), value: metadata.suggestedTitle)
                        suggestionRow(title: String(localized: "Summary"), value: metadata.summary)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tags")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            FlowTags(tags: metadata.suggestedTags)
                        }
                        suggestionRow(title: String(localized: "Collection"), value: metadata.suggestedCollection)
                        if !metadata.unresolvedLinkTargets.isEmpty {
                            suggestionRow(title: String(localized: "Unresolved Links"), value: metadata.unresolvedLinkTargets.map { "[[\($0)]]" }.joined(separator: " "))
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack {
                            suggestionActionButtons(metadata)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            suggestionActionButtons(metadata)
                        }
                    }
                    .controlSize(.small)
                } else {
                    Text(note.aiMetadata?.lastErrorMessage ?? String(localized: "AI organization suggestions appear here after saving or running the button."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var unorganizedPanel: some View {
        VaultPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Unorganized Notes", systemImage: "tray.full")
                        .font(.headline)
                    Spacer()
                    Text("\(unorganizedNotes.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if unorganizedNotes.isEmpty {
                    Text("There are no notes in Unorganized or tagged #Unorganized.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(unorganizedNotes.prefix(4)) { candidate in
                        HStack(spacing: 8) {
                            Image(systemName: candidate.isAIEligible ? "sparkle" : "lock")
                                .foregroundStyle(candidate.isAIEligible ? .mint : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(candidate.tags.map { "#\($0)" }.joined(separator: " "))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    }

                    Button {
                        enqueueUnorganizedNotes()
                    } label: {
                        Label("Send Unorganized Notes to Suggestions", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!canBatchOrganizeUnorganizedNotes)
                }

                if let batchOrganizationMessage {
                    Text(batchOrganizationMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var relatedPanel: some View {
        VaultPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text("Related Notes")
                    .font(.headline)
                if relatedNotes.isEmpty {
                    Text("Related notes appear here when AI organization or link analysis finds them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(relatedNotes) { related in
                        HStack {
                            Image(systemName: "doc.text")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(related.title)
                                    .font(.subheadline)
                                Text(related.collectionName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var importExportPanel: some View {
        VaultPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text("Import / Export")
                    .font(.headline)
                Text("Markdown exports the current note. CSV/JSON exports the whole vault with frontmatter for Obsidian vault workflows.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: exportButtonColumns, alignment: .leading, spacing: 8) {
                    Button("Current Markdown") {
                        prepareExport(text: ImportExportService.exportMarkdown(note: note), type: .plainText, filename: "\(note.title).md")
                    }
                    Button("All CSV") {
                        prepareExport(text: ImportExportService.exportCSV(notes: allNotes), type: .commaSeparatedText, filename: "MindVaultNotes.csv")
                    }
                    Button("All JSON") {
                        let data = (try? ImportExportService.exportJSON(notes: allNotes)) ?? Data("[]".utf8)
                        prepareExport(text: String(data: data, encoding: .utf8) ?? "[]", type: .json, filename: "MindVaultNotes.json")
                    }
                    Button("Import") {
                        isImporting = true
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                if let importErrorMessage {
                    Text(importErrorMessage)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var exportButtonColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 72 : 68), spacing: 8, alignment: .leading)
        ]
    }

    private func prepareExport(text: String, type: UTType, filename: String) {
        exportDocument = MindVaultExportDocument(text: text)
        exportContentType = type
        exportFilename = filename
        isExporting = true
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didStart = url.startAccessingSecurityScopedResource()
            defer {
                if didStart {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            if let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                try ImportExportService.validateImportFileSize(fileSize)
            }
            let text = try String(contentsOf: url, encoding: .utf8)
            let importedNotes = try ImportExportService.parseImport(filename: url.lastPathComponent, text: text)
            let mergedNotes = allNotes + importedNotes
            for importedNote in importedNotes {
                modelContext.insert(importedNote)
                MarkdownIndexingService.reindex(note: importedNote, allNotes: mergedNotes, context: modelContext)
                EmbeddingSearchService.upsertEmbedding(for: importedNote)
            }
            try modelContext.save()
            importErrorMessage = nil
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func hasSuggestion(_ metadata: NoteAIMetadata) -> Bool {
        !metadata.suggestedTitle.isEmpty || !metadata.summary.isEmpty || !metadata.suggestedTags.isEmpty
    }

    private var canBatchOrganizeUnorganizedNotes: Bool {
        aiQueue.availability.isAvailable
            && (entitlement?.remainingAIOrganizeCount ?? 0) > 0
            && unorganizedNotes.contains { $0.isAIEligible }
    }

    private func enqueueUnorganizedNotes() {
        aiQueue.refreshAvailability()
        guard aiQueue.availability.isAvailable else {
            batchOrganizationMessage = aiQueue.availability.message
            return
        }
        guard let entitlement else {
            batchOrganizationMessage = String(localized: "Preparing plan information.")
            return
        }

        let candidates = unorganizedNotes.filter(\.isAIEligible)
        let quota = entitlement.remainingAIOrganizeCount
        guard quota > 0 else {
            batchOrganizationMessage = String(localized: "Not enough monthly AI organization credits.")
            return
        }

        let queued = Array(candidates.prefix(min(quota, candidates.count)))
        queued.forEach { candidate in
            aiQueue.enqueueOrganization(note: candidate, allNotes: allNotes, entitlement: entitlement, context: modelContext)
        }
        batchOrganizationMessage = String(localized: "Added \(queued.count) unorganized notes to the AI organization queue.")
    }

    private func editableSuggestionFields(_ metadata: NoteAIMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            editableTextField(String(localized: "Title"), text: Binding(
                get: { metadata.suggestedTitle },
                set: { metadata.suggestedTitle = $0 }
            ))

            VStack(alignment: .leading, spacing: 4) {
                Text("Summary")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: Binding(
                    get: { metadata.summary },
                    set: { metadata.summary = $0 }
                ))
                .frame(minHeight: 76)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            }

            editableTextField(String(localized: "Tags (comma-separated)"), text: Binding(
                get: { metadata.suggestedTags.joined(separator: ", ") },
                set: { metadata.suggestedTags = cleanedCommaSeparatedValues(from: $0) }
            ))

            editableTextField(String(localized: "Collection"), text: Binding(
                get: { metadata.suggestedCollection },
                set: { metadata.suggestedCollection = $0 }
            ))

            editableTextField(String(localized: "Unresolved Links (comma-separated)"), text: Binding(
                get: { metadata.unresolvedLinkTargets.joined(separator: ", ") },
                set: { metadata.unresolvedLinkTargets = cleanedCommaSeparatedValues(from: $0) }
            ))
        }
    }

    private func editableTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func cleanedCommaSeparatedValues(from text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "# \n\t")) }
            .filter { !$0.isEmpty }
    }

    private func suggestionRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? String(localized: "Not Suggested") : value)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private func suggestionActionButtons(_ metadata: NoteAIMetadata) -> some View {
        Button("Apply") {
            metadata.suggestionStatus = "draft"
            aiQueue.applyAcceptedSuggestion(to: note, context: modelContext)
        }
        .buttonStyle(.borderedProminent)
        .tint(.mint)

        if metadata.suggestionStatus == "editing" {
            Button("Save") {
                metadata.suggestionStatus = "draft"
                try? modelContext.save()
            }
            .buttonStyle(.bordered)
        } else {
            Button("Edit") {
                metadata.suggestionStatus = "editing"
            }
            .buttonStyle(.bordered)
        }

        Button("Dismiss") {
            aiQueue.dismissSuggestion(for: note, context: modelContext)
        }
        .buttonStyle(.bordered)
    }
}

private enum AIInspectorStyle {
    static let background = Color(uiColor: .systemBackground)
}

private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(tags, id: \.self) { tag in
                    TagChip(tag: tag)
                }
            }
        }
    }
}
