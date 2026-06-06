import SwiftUI
import UIKit

struct GraphWorkspaceView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let graph: KnowledgeGraph
    let notes: [Note]
    let selectedNote: Note?
    @Binding var selectedNoteID: UUID?
    @Binding var mode: WorkspaceMode
    var onCreateNote: () -> Void
    var onOpenSelectedNote: (() -> Void)? = nil

    @State private var visibleLinkKinds: Set<LinkKind> = [.wiki, .markdown, .aiRelated]

    private var displayedGraph: KnowledgeGraph {
        let visibleLinks = graph.links.filter { visibleLinkKinds.contains($0.kind) }
        let degreeByID = visibleLinks.reduce(into: [UUID: Int]()) { result, link in
            result[link.sourceID, default: 0] += 1
            result[link.targetID, default: 0] += 1
        }
        let nodes = graph.nodes.map { node in
            GraphNode(
                id: node.id,
                title: node.title,
                tags: node.tags,
                collectionName: node.collectionName,
                weight: Double(max(1, degreeByID[node.id, default: 1])),
                position: node.position,
                isAIEligible: node.isAIEligible
            )
        }
        return KnowledgeGraph(nodes: nodes, links: visibleLinks)
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactWorkspace
            } else {
                regularWorkspace
            }
        }
        .foregroundStyle(ObsidianWorkspaceStyle.primaryText)
        .background(ObsidianWorkspaceStyle.rootBackground.ignoresSafeArea())
        .navigationTitle(horizontalSizeClass == .compact ? "Graph View" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ObsidianWorkspaceStyle.rootBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(ObsidianWorkspaceStyle.panelBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .tint(ObsidianWorkspaceStyle.accent)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    onCreateNote()
                } label: {
                    Label("New Note", systemImage: "square.and.pencil")
                }
            }
        }
    }

    private var compactWorkspace: some View {
        VStack(spacing: horizontalSizeClass == .compact ? 10 : 14) {
            vaultHeader
            header

            ZStack(alignment: .bottom) {
                GraphCanvasView(
                    graph: displayedGraph,
                    selectedNoteID: $selectedNoteID,
                    labelSafeAreaInsets: graphLabelSafeAreaInsets,
                    showsSelectedNodeLabel: selectedNote == nil
                ) { noteID in
                    selectedNoteID = noteID
                    openSelectedNote()
                }

                if let selectedNote {
                    selectedSummary(note: selectedNote)
                        .padding(.horizontal, horizontalSizeClass == .compact ? 10 : 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(minHeight: horizontalSizeClass == .compact ? 340 : 460)
        }
        .padding(16)
    }

    private var regularWorkspace: some View {
        VStack(spacing: 0) {
            graphTabBar
            Divider()
                .overlay(ObsidianWorkspaceStyle.border)

            GeometryReader { proxy in
                let showsRail = proxy.size.width >= 660
                HStack(spacing: 0) {
                    regularGraphPane

                    if showsRail {
                        Divider()
                            .overlay(ObsidianWorkspaceStyle.border)
                        rightRail
                            .frame(width: min(270, max(230, proxy.size.width * 0.30)))
                    }
                }
            }

            Divider()
                .overlay(ObsidianWorkspaceStyle.border)
            workspaceStatusBar
        }
        .background(ObsidianChromeStyle.rootBackground)
    }

    private var graphTabBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(ObsidianWorkspaceStyle.accent)
                Text("Graph view")
                    .font(.caption.weight(.semibold))
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(ObsidianChromeStyle.editorBackground)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                miniToolButton(systemImage: "line.3.horizontal.decrease", title: String(localized: "Display"))
                miniToolButton(systemImage: "arrow.up.arrow.down", title: String(localized: "Sort"))
                miniToolButton(systemImage: "magnifyingglass", title: String(localized: "Search"))
            }
            .padding(.horizontal, 8)
        }
        .foregroundStyle(ObsidianWorkspaceStyle.primaryText)
        .background(ObsidianChromeStyle.tabBarBackground)
        .overlay(alignment: .leading) {
            Text("Graph View")
                .font(.caption2)
                .opacity(0.01)
                .accessibilityHidden(false)
        }
    }

    private var regularGraphPane: some View {
        ZStack(alignment: .topTrailing) {
            GraphCanvasView(
                graph: displayedGraph,
                selectedNoteID: $selectedNoteID,
                labelSafeAreaInsets: EdgeInsets(top: 12, leading: 12, bottom: 36, trailing: 64),
                showsNodeLabels: false,
                showsSelectedNodeLabel: true,
                cornerRadius: 0
            ) { noteID in
                selectedNoteID = noteID
            }

            graphInlineToolbar
                .padding(.top, 10)
                .padding(.trailing, 10)
        }
    }

    private var graphInlineToolbar: some View {
        VStack(spacing: 8) {
            miniToolButton(systemImage: "gearshape", title: String(localized: "Graph Settings"))
            miniToolButton(systemImage: "wand.and.stars", title: String(localized: "AI Layout"))
            miniToolButton(systemImage: "number", title: String(localized: "Tags"))
        }
        .padding(6)
        .background(ObsidianWorkspaceStyle.floatingPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(ObsidianWorkspaceStyle.border, lineWidth: 1)
        }
    }

    private var rightRail: some View {
        ScrollView {
            VStack(spacing: 0) {
                selectedRailPanel
                railDivider
                mentionsPanel(title: String(localized: "Linked Mentions"), count: backlinkCount)
                railDivider
                mentionsPanel(title: String(localized: "Unlinked Mentions"), count: unlinkedMentionCount)
                railDivider
                graphLegendPanel
                railDivider
                ObsidianMiniCalendar()
                    .padding(14)
                railDivider
                graphStatsPanel
            }
        }
        .background(ObsidianChromeStyle.panelBackground)
    }

    private var selectedRailPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundStyle(ObsidianWorkspaceStyle.accent)
                Text(selectedNote?.title ?? "No active note")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            if let selectedNote {
                Text(selectedNote.excerpt)
                    .font(.caption)
                    .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
                    .lineLimit(3)

                HStack(spacing: 6) {
                    ForEach(selectedNote.tags.prefix(3), id: \.self) { tag in
                        obsidianTagChip(tag: tag)
                    }
                }

                Button {
                    openSelectedNote()
                } label: {
                    Label("Open note", systemImage: "arrow.right")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(ObsidianWorkspaceStyle.accent)
                .padding(.top, 2)

                if !selectedConnectionReasons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Why It Connects")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ObsidianWorkspaceStyle.primaryText)
                        ForEach(selectedConnectionReasons.prefix(3)) { reason in
                            connectionReasonRow(reason)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mentionsPanel(title: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ObsidianWorkspaceStyle.primaryText)
                Spacer()
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ObsidianWorkspaceStyle.accent)
            }

            if count == 0 {
                Text("No mentions")
                    .font(.caption2)
                    .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
            } else {
                ForEach(mentionNotes.prefix(3)) { note in
                    Button {
                        selectedNoteID = note.id
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text(note.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var graphLegendPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Relationship Types")
                .font(.caption.weight(.semibold))
                Spacer()
                Text("\(displayedGraph.links.count)/\(graph.links.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
            }

            linkKindToggle(kind: .wiki)
            linkKindToggle(kind: .markdown)
            linkKindToggle(kind: .aiRelated)
            linkKindToggle(kind: .tagCooccurrence)
        }
        .font(.caption)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func linkKindToggle(kind: LinkKind) -> some View {
        Toggle(isOn: linkKindBinding(kind)) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(edgeColor(for: kind))
                        .frame(width: 7, height: 7)
                    Text(edgeTitle(for: kind))
                        .foregroundStyle(ObsidianWorkspaceStyle.primaryText)
                    Spacer()
                    Text("\(kindCount(kind))")
                        .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
                }
                Text(edgeDescription(for: kind))
                    .font(.caption2)
                    .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
                    .lineLimit(2)
            }
        }
        .toggleStyle(.switch)
        .tint(ObsidianWorkspaceStyle.accent)
    }

    private func connectionReasonRow(_ reason: ConnectionReason) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(edgeColor(for: reason.kind))
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(reason.noteTitle)
                    .foregroundStyle(ObsidianWorkspaceStyle.primaryText)
                    .lineLimit(1)
                Text(reason.summary)
                    .font(.caption2)
                    .lineLimit(1)
            }
                .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
            Spacer()
        }
    }

    private var graphStatsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vault")
                .font(.caption.weight(.semibold))
            statLine(String(localized: "Notes"), "\(displayedGraph.nodes.count)")
            statLine(String(localized: "Visible Links"), "\(displayedGraph.links.count)")
            statLine(String(localized: "All Links"), "\(graph.links.count)")
            statLine(String(localized: "AI Enabled"), "\(notes.filter(\.isAIEligible).count)")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(ObsidianWorkspaceStyle.primaryText)
        }
        .font(.caption)
    }

    private var railDivider: some View {
        Divider()
            .overlay(ObsidianWorkspaceStyle.border)
    }

    private var workspaceStatusBar: some View {
        HStack(spacing: 10) {
            Text("\(displayedGraph.nodes.count) notes")
            Text("\(displayedGraph.links.count) visible links")
            Text("\(notes.reduce(0) { $0 + ($1.content?.wordCount ?? 0) }) words")
            Text("\(notes.reduce(0) { $0 + ($1.content?.characterCount ?? 0) }) characters")
            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(ObsidianChromeStyle.tabBarBackground)
    }

    private func miniToolButton(systemImage: String, title: String) -> some View {
        Button {} label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
        .background(Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel(title)
    }

    private var backlinkCount: Int {
        guard let selectedNote else { return 0 }
        return mentionNotes.filter { $0.markdown.contains("[[\(selectedNote.title)]]") }.count
    }

    private var unlinkedMentionCount: Int {
        guard let selectedNote else { return 0 }
        return notes.filter { note in
            note.id != selectedNote.id
                && !note.markdown.contains("[[\(selectedNote.title)]]")
                && note.markdown.localizedCaseInsensitiveContains(selectedNote.title)
        }.count
    }

    private var mentionNotes: [Note] {
        guard let selectedNote else { return [] }
        return notes.filter { note in
            note.id != selectedNote.id && note.markdown.contains("[[\(selectedNote.title)]]")
        }
    }

    private func kindCount(_ kind: LinkKind) -> Int {
        graph.links.filter { $0.kind == kind }.count
    }

    private func linkKindBinding(_ kind: LinkKind) -> Binding<Bool> {
        Binding(
            get: { visibleLinkKinds.contains(kind) },
            set: { isVisible in
                if isVisible {
                    visibleLinkKinds.insert(kind)
                } else {
                    visibleLinkKinds.remove(kind)
                }
            }
        )
    }

    private func edgeColor(for kind: LinkKind) -> Color {
        switch kind {
        case .wiki: ObsidianWorkspaceStyle.accent
        case .markdown: Color(red: 0.00, green: 0.66, blue: 0.86)
        case .aiRelated: ObsidianChromeStyle.amber
        case .tagCooccurrence: ObsidianChromeStyle.violet
        }
    }

    private func edgeTitle(for kind: LinkKind) -> String {
        switch kind {
        case .wiki: String(localized: "Explicit Links")
        case .markdown: String(localized: "Markdown Links")
        case .aiRelated: String(localized: "AI Suggestions")
        case .tagCooccurrence: String(localized: "Shared Tags")
        }
    }

    private func edgeDescription(for kind: LinkKind) -> String {
        switch kind {
        case .wiki: String(localized: "Direct relationships created with [[Note Name]].")
        case .markdown: String(localized: "Direct relationships created with [text](note.md).")
        case .aiRelated: String(localized: "Relationships suggested by AI organization.")
        case .tagCooccurrence: String(localized: "Relationships that share meaningful tags.")
        }
    }

    private var selectedConnectionReasons: [ConnectionReason] {
        guard let selectedNoteID else { return [] }
        return graph.links
            .filter { link in
                visibleLinkKinds.contains(link.kind)
                    && (link.sourceID == selectedNoteID || link.targetID == selectedNoteID)
            }
            .compactMap { link in
                let otherID = link.sourceID == selectedNoteID ? link.targetID : link.sourceID
                guard let noteTitle = title(for: otherID) else { return nil }
                return ConnectionReason(noteTitle: noteTitle, kind: link.kind, summary: edgeDescription(for: link.kind))
            }
    }

    private func title(for noteID: UUID) -> String? {
        graph.nodes.first { $0.id == noteID }?.title
    }

    private var graphLabelSafeAreaInsets: EdgeInsets {
        EdgeInsets(
            top: 6,
            leading: 6,
            bottom: selectedNote == nil ? 10 : (horizontalSizeClass == .compact ? 94 : 126),
            trailing: 52
        )
    }

    private var vaultHeader: some View {
        obsidianPanel {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(ObsidianWorkspaceStyle.accent.opacity(0.16))
                    Image(systemName: "folder")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ObsidianWorkspaceStyle.accent)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MindVault")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ObsidianWorkspaceStyle.primaryText)
                    Text("\(notes.count) Markdown notes")
                        .font(.caption2)
                        .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                vaultActionButton(systemImage: "magnifyingglass", title: String(localized: "Search")) {
                    mode = .search
                }

                vaultActionButton(systemImage: "gearshape", title: String(localized: "Settings")) {
                    mode = .settings
                }
            }
        }
    }

    private var header: some View {
        obsidianPanel {
            if horizontalSizeClass == .compact {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("Knowledge Graph")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(ObsidianWorkspaceStyle.primaryText)

                        Spacer(minLength: 8)

                        HStack(alignment: .top, spacing: 16) {
                            stat(title: String(localized: "Notes"), value: "\(displayedGraph.nodes.count)")
                            stat(title: String(localized: "Visible Links"), value: "\(displayedGraph.links.count)")
                            stat(title: String(localized: "AI Enabled"), value: "\(notes.filter(\.isAIEligible).count)")
                        }
                    }

                    Text("Focused on explicit links and AI suggestions. Add shared tags from the right filter.")
                        .font(.caption)
                        .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
                        .lineLimit(1)
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Knowledge Graph")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(ObsidianWorkspaceStyle.primaryText)
                        Text("Tap a node to move to the note. The graph focuses on explicit links and AI suggestions.")
                            .font(.subheadline)
                            .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
                            .lineLimit(2)
                    }

                    Spacer()

                    stat(title: String(localized: "Notes"), value: "\(displayedGraph.nodes.count)")
                    stat(title: String(localized: "Visible Links"), value: "\(displayedGraph.links.count)")
                    stat(title: String(localized: "AI Enabled"), value: "\(notes.filter(\.isAIEligible).count)")
                }
            }
        }
    }

    private func vaultActionButton(systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(ObsidianWorkspaceStyle.primaryText)
        .background(ObsidianWorkspaceStyle.tagBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityLabel(title)
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(horizontalSizeClass == .compact ? .subheadline.weight(.semibold) : .headline)
                .foregroundStyle(ObsidianWorkspaceStyle.primaryText)
            Text(title)
                .font(horizontalSizeClass == .compact ? .caption2 : .caption)
                .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
        }
        .frame(minWidth: horizontalSizeClass == .compact ? 38 : 54)
    }

    private func selectedSummary(note: Note) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(ObsidianWorkspaceStyle.accent.opacity(0.16))
                    .frame(width: 34, height: 34)
                Image(systemName: "circle.hexagongrid")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ObsidianWorkspaceStyle.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(note.title)
                    .font(.headline)
                    .foregroundStyle(ObsidianWorkspaceStyle.primaryText)
                    .lineLimit(1)
                Text(note.excerpt)
                    .font(.subheadline)
                    .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
                    .lineLimit(horizontalSizeClass == .compact ? 1 : 2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(note.tags.prefix(horizontalSizeClass == .compact ? 3 : 5), id: \.self) { tag in
                            obsidianTagChip(tag: tag)
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            Button {
                openSelectedNote()
            } label: {
                Label("Open", systemImage: "arrow.right")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(ObsidianWorkspaceStyle.accent)
            .foregroundStyle(ObsidianWorkspaceStyle.buttonText)
        }
        .padding(12)
        .background(ObsidianWorkspaceStyle.floatingPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(ObsidianWorkspaceStyle.border, lineWidth: 1)
        }
    }

    private func obsidianPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(ObsidianWorkspaceStyle.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(ObsidianWorkspaceStyle.border, lineWidth: 1)
            }
    }

    private func obsidianTagChip(tag: String) -> some View {
        Text("#\(tag)")
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(ObsidianWorkspaceStyle.tagBackground, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(ObsidianWorkspaceStyle.border.opacity(0.7), lineWidth: 0.7)
            }
            .foregroundStyle(ObsidianWorkspaceStyle.secondaryText)
    }

    private func openSelectedNote() {
        if let onOpenSelectedNote {
            onOpenSelectedNote()
        } else {
            mode = .editor
        }
    }
}

private struct ConnectionReason: Identifiable {
    let id = UUID()
    let noteTitle: String
    let kind: LinkKind
    let summary: String
}

private enum ObsidianWorkspaceStyle {
    static let rootBackground = workspaceColor(
        light: UIColor(red: 0.955, green: 0.955, blue: 0.950, alpha: 1),
        dark: UIColor(red: 0.096, green: 0.096, blue: 0.094, alpha: 1)
    )
    static let panelBackground = workspaceColor(
        light: UIColor(red: 0.985, green: 0.985, blue: 0.975, alpha: 1),
        dark: UIColor(red: 0.130, green: 0.130, blue: 0.126, alpha: 1)
    )
    static let floatingPanel = workspaceColor(
        light: UIColor(red: 0.990, green: 0.990, blue: 0.980, alpha: 0.96),
        dark: UIColor(red: 0.118, green: 0.122, blue: 0.128, alpha: 0.94)
    )
    static let tagBackground = workspaceColor(
        light: UIColor(red: 0.900, green: 0.910, blue: 0.905, alpha: 1),
        dark: UIColor(red: 0.190, green: 0.198, blue: 0.206, alpha: 1)
    )
    static let border = workspaceColor(
        light: UIColor(red: 0.780, green: 0.790, blue: 0.780, alpha: 0.72),
        dark: UIColor(red: 0.235, green: 0.240, blue: 0.245, alpha: 0.86)
    )
    static let primaryText = workspaceColor(
        light: UIColor(red: 0.105, green: 0.110, blue: 0.115, alpha: 1),
        dark: UIColor(red: 0.870, green: 0.890, blue: 0.910, alpha: 1)
    )
    static let secondaryText = workspaceColor(
        light: UIColor(red: 0.390, green: 0.420, blue: 0.435, alpha: 1),
        dark: UIColor(red: 0.580, green: 0.620, blue: 0.660, alpha: 1)
    )
    static let accent = Color(red: 0.00, green: 0.72, blue: 0.68)
    static let buttonText = workspaceColor(
        light: UIColor.white,
        dark: UIColor(red: 0.050, green: 0.080, blue: 0.090, alpha: 1)
    )
}

private func workspaceColor(light: UIColor, dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}
