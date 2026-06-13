import AppIntents
import Foundation

enum MindVaultIntentDestination: String, AppEnum {
    case graph
    case notes
    case search
    case settings

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "MindVault Destination")

    static var caseDisplayRepresentations: [MindVaultIntentDestination: DisplayRepresentation] = [
        .graph: DisplayRepresentation(title: "Graph"),
        .notes: DisplayRepresentation(title: "Notes"),
        .search: DisplayRepresentation(title: "Search"),
        .settings: DisplayRepresentation(title: "Settings")
    ]
}

struct PendingMindVaultDraft: Equatable {
    var title: String
    var markdown: String
}

enum MindVaultAppIntentRouter {
    static let routeNotification = Notification.Name("MindVaultAppIntentRouteRequested")

    private static let destinationKey = "appIntent.pendingDestination"
    private static let draftTitleKey = "appIntent.pendingDraftTitle"
    private static let draftMarkdownKey = "appIntent.pendingDraftMarkdown"

    static func request(destination: MindVaultIntentDestination) {
        UserDefaults.standard.set(destination.rawValue, forKey: destinationKey)
        NotificationCenter.default.post(name: routeNotification, object: destination.rawValue)
    }

    static func requestDraft(title: String, markdown: String) {
        UserDefaults.standard.set(title, forKey: draftTitleKey)
        UserDefaults.standard.set(markdown, forKey: draftMarkdownKey)
        request(destination: .notes)
    }

    static func consumePendingDraft() -> PendingMindVaultDraft? {
        guard UserDefaults.standard.object(forKey: draftTitleKey) != nil else {
            return nil
        }

        let draft = PendingMindVaultDraft(
            title: UserDefaults.standard.string(forKey: draftTitleKey) ?? "",
            markdown: UserDefaults.standard.string(forKey: draftMarkdownKey) ?? ""
        )
        UserDefaults.standard.removeObject(forKey: draftTitleKey)
        UserDefaults.standard.removeObject(forKey: draftMarkdownKey)
        UserDefaults.standard.removeObject(forKey: destinationKey)
        return draft
    }

    static func consumePendingDestination() -> WorkspaceMode? {
        guard let rawValue = UserDefaults.standard.string(forKey: destinationKey) else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: destinationKey)
        return workspaceMode(for: rawValue)
    }

    static func workspaceMode(for rawValue: String) -> WorkspaceMode? {
        switch MindVaultIntentDestination(rawValue: rawValue) {
        case .graph:
            return .graph
        case .notes:
            return .editor
        case .search:
            return .search
        case .settings:
            return .settings
        case nil:
            return nil
        }
    }
}

struct OpenMindVaultDestinationIntent: AppIntent {
    static var title: LocalizedStringResource = "Open MindVault"
    static var description = IntentDescription("Open MindVault directly to the graph, notes, search, or settings.")
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Destination")
    var destination: MindVaultIntentDestination

    init() {
        destination = .graph
    }

    init(destination: MindVaultIntentDestination) {
        self.destination = destination
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        MindVaultAppIntentRouter.request(destination: destination)
        return .result()
    }
}

struct CreateMindVaultDraftIntent: AppIntent {
    static var title: LocalizedStringResource = "Create MindVault Note"
    static var description = IntentDescription("Create a new Markdown note draft in MindVault from Shortcuts.")
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Title")
    var noteTitle: String

    @Parameter(title: "Body")
    var markdown: String

    init() {
        noteTitle = String(localized: "Shortcut Note")
        markdown = ""
    }

    init(noteTitle: String, markdown: String = "") {
        self.noteTitle = noteTitle
        self.markdown = markdown
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        MindVaultAppIntentRouter.requestDraft(title: noteTitle, markdown: markdown)
        return .result()
    }
}

struct MindVaultShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenMindVaultDestinationIntent(destination: .graph),
            phrases: [
                "Open \(.applicationName) graph",
                "Show \(.applicationName) graph"
            ],
            shortTitle: "Open Graph",
            systemImageName: "point.3.connected.trianglepath.dotted"
        )

        AppShortcut(
            intent: CreateMindVaultDraftIntent(),
            phrases: [
                "Create a note in \(.applicationName)",
                "Add a note to \(.applicationName)"
            ],
            shortTitle: "Create Note",
            systemImageName: "square.and.pencil"
        )
    }
}
