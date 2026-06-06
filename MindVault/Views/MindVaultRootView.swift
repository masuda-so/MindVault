import SwiftData
import SwiftUI

struct MindVaultRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query(sort: \NoteCollection.sortOrder) private var collections: [NoteCollection]
    @Query private var links: [NoteLink]
    @Query private var graphEdges: [GraphEdge]
    @Query private var entitlements: [SubscriptionEntitlement]

    @State private var selectedNoteID: UUID?
    @State private var mode: WorkspaceMode = .graph
    @State private var isCompactEditorPresented = false
    @State private var searchText = ""
    @State private var selectedCollection: String?
    @State private var selectedTag: String?
    @State private var dateFilter: NoteDateFilter = .all
    @AppStorage("vaultAppearance") private var vaultAppearanceRawValue = VaultAppearance.system.rawValue

    private var selectedNote: Note? {
        notes.first { $0.id == selectedNoteID } ?? defaultSelectedNote
    }

    private var defaultSelectedNote: Note? {
        notes.first { $0.isPinned } ?? notes.first
    }

    private var entitlement: SubscriptionEntitlement? {
        entitlements.first
    }

    private var graph: KnowledgeGraph {
        GraphBuilder.build(notes: notes, links: links, aiEdges: graphEdges)
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactShell
            } else {
                regularShell
            }
        }
        .task {
            if !ProcessInfo.processInfo.isRunningAppHostedUnitTests {
                SeedData.ensureSeedData(context: modelContext)
            }
            if selectedNoteID == nil {
                selectedNoteID = defaultSelectedNote?.id
            }
            handlePendingAppIntentRequest()
        }
        .onChange(of: notes.count) { _, _ in
            if selectedNoteID == nil {
                selectedNoteID = defaultSelectedNote?.id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: MindVaultAppIntentRouter.routeNotification)) { _ in
            handlePendingAppIntentRequest()
        }
        .preferredColorScheme(vaultAppearance.colorScheme)
    }

    private var vaultAppearance: VaultAppearance {
        VaultAppearance(rawValue: vaultAppearanceRawValue) ?? .system
    }

    private var regularShell: some View {
        NavigationSplitView {
            SidebarView(
                notes: notes,
                collections: collections,
                tags: tags,
                entitlement: entitlement,
                mode: $mode,
                selectedCollection: $selectedCollection,
                selectedTag: $selectedTag
            )
        } content: {
            if mode == .graph {
                ObsidianReadingPane(
                    note: selectedNote,
                    notes: notes,
                    selectedNoteID: $selectedNoteID,
                    onCreateNote: {
                        createNote(openEditor: false)
                    }
                )
            } else {
                NoteListView(
                    notes: notes,
                    entitlement: entitlement,
                    selectedNoteID: $selectedNoteID,
                    mode: $mode,
                    searchText: $searchText,
                    selectedCollection: $selectedCollection,
                    selectedTag: $selectedTag,
                    dateFilter: $dateFilter,
                    onOpenDailyNote: { date in
                        createDailyNote(for: date)
                    }
                )
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            createNote()
                        } label: {
                            Label("New Note", systemImage: "square.and.pencil")
                        }
                        Button {
                            createDailyNote(for: .now)
                        } label: {
                            Label("Daily", systemImage: "calendar")
                        }
                    }
                }
            }
        } detail: {
            detailWorkspace
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var compactShell: some View {
        TabView(selection: $mode) {
            NavigationStack {
                GraphWorkspaceView(
                    graph: graph,
                    notes: notes,
                    selectedNote: selectedNote,
                    selectedNoteID: $selectedNoteID,
                    mode: $mode,
                    onCreateNote: {
                        createNote(openEditor: false)
                    },
                    onOpenSelectedNote: {
                        openCompactEditor()
                    }
                )
            }
            .tabItem { Label("Graph", systemImage: WorkspaceMode.graph.systemImage) }
            .tag(WorkspaceMode.graph)

            NavigationStack {
                NoteListView(
                    notes: notes,
                    entitlement: entitlement,
                    selectedNoteID: $selectedNoteID,
                    mode: $mode,
                    searchText: $searchText,
                    selectedCollection: $selectedCollection,
                    selectedTag: $selectedTag,
                    dateFilter: $dateFilter,
                    onOpenNote: {
                        openCompactEditor()
                    },
                    onOpenDailyNote: { date in
                        createDailyNote(for: date)
                        openCompactEditor()
                    }
                )
                .navigationDestination(isPresented: $isCompactEditorPresented) {
                    compactEditor
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            createDailyNote(for: .now)
                            openCompactEditor()
                        } label: {
                            Label("Daily", systemImage: "calendar")
                        }
                        Button {
                            createNote()
                            isCompactEditorPresented = true
                        } label: {
                            Label("New Note", systemImage: "square.and.pencil")
                        }
                    }
                }
            }
            .tabItem { Label("Notes", systemImage: WorkspaceMode.editor.systemImage) }
            .tag(WorkspaceMode.editor)

            NavigationStack {
                SearchChatView(
                    notes: notes,
                    entitlement: entitlement,
                    selectedNoteID: $selectedNoteID,
                    mode: $mode,
                    onOpenNote: {
                        openCompactEditor()
                    }
                )
            }
            .tabItem { Label("Search", systemImage: WorkspaceMode.search.systemImage) }
            .tag(WorkspaceMode.search)

            NavigationStack {
                if let entitlement {
                    PlanSettingsView(entitlement: entitlement, notes: notes)
                } else {
                    EmptyStateView(systemImage: "gearshape", title: String(localized: "Preparing Settings"), message: String(localized: "Creating starter data."))
                }
            }
            .tabItem { Label("Settings", systemImage: WorkspaceMode.settings.systemImage) }
            .tag(WorkspaceMode.settings)
        }
        .onChange(of: mode) { _, newMode in
            if newMode != .editor {
                isCompactEditorPresented = false
            }
        }
    }

    @ViewBuilder
    private var detailWorkspace: some View {
        switch mode {
        case .graph:
            GraphWorkspaceView(
                graph: graph,
                notes: notes,
                selectedNote: selectedNote,
                selectedNoteID: $selectedNoteID,
                mode: $mode,
                onCreateNote: {
                    createNote(openEditor: false)
                }
            )
        case .editor:
            if let selectedNote {
                HStack(spacing: 0) {
                    NoteEditorView(note: selectedNote, allNotes: notes, links: links, entitlement: entitlement)
                    Divider()
                    AIInspectorView(note: selectedNote, allNotes: notes, entitlement: entitlement)
                }
            } else {
                EmptyStateView(systemImage: "doc.text.magnifyingglass", title: String(localized: "No Notes"), message: String(localized: "Create a new note and it will appear here."))
            }
        case .search:
            SearchChatView(notes: notes, entitlement: entitlement, selectedNoteID: $selectedNoteID, mode: $mode)
        case .settings:
            if let entitlement {
                PlanSettingsView(entitlement: entitlement, notes: notes)
            } else {
                EmptyStateView(systemImage: "gearshape", title: String(localized: "Preparing Settings"), message: String(localized: "Creating starter data."))
            }
        }
    }

    @ViewBuilder
    private var compactEditor: some View {
        if let selectedNote {
            NoteEditorView(
                note: selectedNote,
                allNotes: notes,
                links: links,
                entitlement: entitlement,
                showsInspectorButton: true
            )
        }
    }

    private func createNote(
        title: String = String(localized: "Untitled Note"),
        markdown: String? = nil,
        collectionName: String? = nil,
        tags: [String]? = nil,
        openEditor: Bool = true
    ) {
        let unorganizedTag = String(localized: "Unorganized")
        let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "Untitled Note") : title
        let resolvedMarkdown = markdown ?? "# \(resolvedTitle)\n\n\(String(localized: "Start writing in Markdown here."))\n\n#\(unorganizedTag)"
        let parsedTags = MarkdownIndexingService.parse(resolvedMarkdown).tags
        let note = Note(
            title: resolvedTitle,
            markdown: resolvedMarkdown,
            collectionName: collectionName ?? selectedCollection ?? unorganizedTag,
            tags: tags ?? selectedTag.map { [$0] } ?? (parsedTags.isEmpty ? [unorganizedTag] : parsedTags)
        )
        modelContext.insert(note)
        MarkdownIndexingService.reindex(note: note, allNotes: notes + [note], context: modelContext)
        EmbeddingSearchService.upsertEmbedding(for: note)
        try? modelContext.save()
        selectedNoteID = note.id
        mode = openEditor ? .editor : .graph
    }

    private func createDailyNote(for date: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let title = dailyNoteTitle(for: date)
        if let existing = notes.first(where: { dailyDate(for: $0) == normalizedDate || $0.title == title }) {
            if existing.dailyDate == nil {
                existing.dailyDate = normalizedDate
            }
            selectedNoteID = existing.id
            mode = .editor
            return
        }
        let note = Note(
            title: title,
            markdown: String(localized: "## Today's Notes\n\n- \n\n#Journal"),
            collectionName: String(localized: "Journal"),
            createdAt: date,
            updatedAt: date,
            tags: [String(localized: "Journal")],
            isDailyNote: true,
            dailyDate: date
        )
        modelContext.insert(note)
        MarkdownIndexingService.reindex(note: note, allNotes: notes + [note], context: modelContext)
        try? modelContext.save()
        selectedNoteID = note.id
        mode = .editor
    }

    private func dailyNoteTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        return "\(String(localized: "Daily Note")) \(formatter.string(from: date))"
    }

    private func dailyDate(for note: Note) -> Date? {
        guard note.isDailyNote else { return nil }
        if let dailyDate = note.dailyDate {
            return Calendar.current.startOfDay(for: dailyDate)
        }
        let dateText = note.title
            .replacingOccurrences(of: "Daily Note Example ", with: "")
            .replacingOccurrences(of: "Daily Note ", with: "")
            .replacingOccurrences(of: "デイリーノートの例 ", with: "")
            .replacingOccurrences(of: "デイリーノート ", with: "")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.date(from: dateText).map { Calendar.current.startOfDay(for: $0) }
    }

    private func openCompactEditor() {
        mode = .editor
        isCompactEditorPresented = selectedNoteID != nil
    }

    private func handlePendingAppIntentRequest() {
        if let draft = MindVaultAppIntentRouter.consumePendingDraft() {
            createNote(
                title: draft.title,
                markdown: markdownForDraft(draft),
                collectionName: String(localized: "Unorganized"),
                openEditor: true
            )
            return
        }

        guard let requestedMode = MindVaultAppIntentRouter.consumePendingDestination() else {
            return
        }
        routeToAppIntentMode(requestedMode)
    }

    private func markdownForDraft(_ draft: PendingMindVaultDraft) -> String {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "Shortcut Note") : draft.title
        let body = draft.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty {
            return "# \(title)\n\n#\(String(localized: "Unorganized"))"
        }
        return body
    }

    private func routeToAppIntentMode(_ requestedMode: WorkspaceMode) {
        if selectedNoteID == nil {
            selectedNoteID = defaultSelectedNote?.id
        }
        mode = requestedMode
        isCompactEditorPresented = requestedMode == .editor && horizontalSizeClass == .compact && selectedNoteID != nil
    }
}
