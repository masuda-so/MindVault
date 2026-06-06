import SwiftData
import SwiftUI

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AIJobQueue.self) private var aiQueue

    @Bindable var note: Note
    let allNotes: [Note]
    let links: [NoteLink]
    let entitlement: SubscriptionEntitlement?
    let showsInspectorButton: Bool

    @State private var draftMarkdown: String
    @State private var showsPreview = true
    @State private var isShowingInspector = false
    @State private var autosaveTask: Task<Void, Never>?
    @State private var lastSavedAt = Date.now

    init(
        note: Note,
        allNotes: [Note],
        links: [NoteLink],
        entitlement: SubscriptionEntitlement?,
        showsInspectorButton: Bool = false
    ) {
        self.note = note
        self.allNotes = allNotes
        self.links = links
        self.entitlement = entitlement
        self.showsInspectorButton = showsInspectorButton
        _draftMarkdown = State(initialValue: note.markdown)
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()
            if showsPreview {
                MarkdownPreview(markdown: draftMarkdown)
            } else {
                TextEditor(text: $draftMarkdown)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .accessibilityIdentifier("markdownEditor")
            }
            Divider()
            editorFooter
        }
        .navigationTitle(editorNavigationTitle)
        .navigationBarTitleDisplayMode(horizontalSizeClass == .compact ? .inline : .automatic)
        .onAppear {
            draftMarkdown = note.markdown
            note.lastOpenedAt = .now
        }
        .onChange(of: draftMarkdown) { _, _ in
            scheduleAutosave()
        }
        .onChange(of: note.title) { _, _ in
            scheduleAutosave()
        }
        .onChange(of: note.isAIEligible) { _, _ in
            saveDraft()
        }
        .onChange(of: note.id) { _, _ in
            draftMarkdown = note.markdown
        }
        .sheet(isPresented: inspectorPresentationBinding(isCompact: false)) {
            inspectorNavigation()
        }
        .fullScreenCover(isPresented: inspectorPresentationBinding(isCompact: true)) {
            inspectorNavigation(showsCloseButton: true)
        }
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            if horizontalSizeClass == .compact {
                TextField("Title", text: $note.title)
                    .font(.title.weight(.semibold))
                    .textFieldStyle(.plain)
                    .onSubmit { scheduleAutosave() }

                HStack(spacing: 10) {
                    Toggle("AI Eligible", isOn: $note.isAIEligible)
                        .toggleStyle(.switch)
                        .font(.caption)
                        .accessibilityIdentifier("aiEligibilityToggle")

                    Spacer(minLength: 8)

                    if showsInspectorButton {
                        Button {
                            isShowingInspector = true
                        } label: {
                            Label("AI Suggestions", systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("openAIInspectorButton")
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(note.tags, id: \.self) { tag in
                            TagChip(tag: tag)
                        }
                    }
                }

                Picker("View", selection: $showsPreview) {
                    Text("Markdown").tag(false)
                    Text("Preview").tag(true)
                }
                .pickerStyle(.segmented)
            } else {
                HStack {
                    TextField("Title", text: $note.title)
                        .font(.title.weight(.semibold))
                        .textFieldStyle(.plain)
                        .onSubmit { scheduleAutosave() }

                    Toggle("AI Eligible", isOn: $note.isAIEligible)
                        .toggleStyle(.switch)
                        .font(.caption)
                        .accessibilityIdentifier("aiEligibilityToggle")

                    if showsInspectorButton {
                        Button {
                            isShowingInspector = true
                        } label: {
                            Label("AI Suggestions", systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("openAIInspectorButton")
                    }
                }

                HStack(spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(note.tags, id: \.self) { tag in
                                TagChip(tag: tag)
                            }
                        }
                    }
                    Spacer()
                    Picker("View", selection: $showsPreview) {
                        Text("Markdown").tag(false)
                        Text("Preview").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
        }
        .padding(16)
    }

    private var editorNavigationTitle: String {
        horizontalSizeClass == .compact ? "" : note.title
    }

    private var editorFooter: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactEditorFooter
            } else {
                regularEditorFooter
            }
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var compactEditorFooter: some View {
        HStack(spacing: 10) {
            autosaveLabel
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer()

            if !backlinks.isEmpty {
                backlinksMenu(labelStyle: .iconOnly)
            }

            Button {
                createDailyReference()
            } label: {
                Image(systemName: "calendar.badge.plus")
            }
            .accessibilityLabel("Add to Daily")
        }
    }

    private var regularEditorFooter: some View {
        HStack(spacing: 12) {
            autosaveLabel

            Spacer()

            if !backlinks.isEmpty {
                backlinksMenu(labelStyle: .titleAndIcon)
            }

            Button {
                createDailyReference()
            } label: {
                Label("Add to Daily", systemImage: "calendar.badge.plus")
            }
        }
    }

    private var autosaveLabel: some View {
        Label("Autosaved: \(lastSavedAt.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle")
            .foregroundStyle(.secondary)
    }

    private func backlinksMenu(labelStyle: LabelStyleOption) -> some View {
        Menu {
            ForEach(backlinks) { backlink in
                Text(backlink.title)
            }
        } label: {
            if labelStyle == .iconOnly {
                Image(systemName: "link")
                    .accessibilityLabel("Backlinks \(backlinks.count)")
            } else {
                Label("Backlinks \(backlinks.count)", systemImage: "link")
            }
        }
    }

    private enum LabelStyleOption {
        case iconOnly
        case titleAndIcon
    }

    private var backlinks: [Note] {
        MarkdownIndexingService.backlinks(to: note, links: links, notes: allNotes)
    }

    private func inspectorPresentationBinding(isCompact: Bool) -> Binding<Bool> {
        Binding(
            get: { isShowingInspector && (horizontalSizeClass == .compact) == isCompact },
            set: { isPresented in
                if !isPresented {
                    isShowingInspector = false
                }
            }
        )
    }

    private func inspectorNavigation(showsCloseButton: Bool = false) -> some View {
        NavigationStack {
            AIInspectorView(note: note, allNotes: allNotes, entitlement: entitlement)
                .toolbar {
                    if showsCloseButton {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") {
                                isShowingInspector = false
                            }
                        }
                    }
                }
        }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            saveDraft()
        }
    }

    private func saveDraft() {
        note.content?.updateMarkdown(draftMarkdown)
        note.updatedAt = .now
        lastSavedAt = .now
        MarkdownIndexingService.reindex(note: note, allNotes: allNotes, context: modelContext)
        EmbeddingSearchService.upsertEmbedding(for: note)
        if shouldQueueAutomaticOrganization {
            aiQueue.enqueueOrganization(note: note, allNotes: allNotes, entitlement: entitlement, context: modelContext)
        }
        try? modelContext.save()
    }

    private var shouldQueueAutomaticOrganization: Bool {
        guard note.isAIEligible else { return false }
        guard aiQueue.availability.isAvailable else { return false }
        let lastOrganizedAt = note.aiMetadata?.lastOrganizedAt ?? .distantPast
        return Date.now.timeIntervalSince(lastOrganizedAt) > 300
    }

    private func createDailyReference() {
        draftMarkdown += "\n\n- Review [[\(note.title)]]"
        scheduleAutosave()
    }
}

private struct MarkdownPreview: View {
    let markdown: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(markdown.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, line in
                    previewLine(String(line))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
    }

    @ViewBuilder
    private func previewLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("## ") {
            Text(trimmed.replacingOccurrences(of: "## ", with: ""))
                .font(.title3.weight(.semibold))
                .padding(.top, 8)
        } else if trimmed.hasPrefix("# ") {
            Text(trimmed.replacingOccurrences(of: "# ", with: ""))
                .font(.title.weight(.bold))
        } else if trimmed.hasPrefix("- ") {
            Text("• \(trimmed.dropFirst(2))")
                .font(.body)
        } else if trimmed.contains("[[") {
            Text(trimmed)
                .font(.body)
                .foregroundStyle(.mint)
        } else {
            Text(trimmed.isEmpty ? " " : trimmed)
                .font(.body)
        }
    }
}
