import Foundation
import SwiftData

enum AIJobStatus: String, Codable, CaseIterable {
    case queued
    case running
    case completed
    case failed
    case skipped
}

enum LinkKind: String, Codable, CaseIterable {
    case wiki
    case markdown
    case aiRelated
    case tagCooccurrence
}

enum SubscriptionPlan: String, Codable, CaseIterable, Identifiable {
    case free
    case pro
    case team

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free: "Free"
        case .pro: "Pro"
        case .team: "Team"
        }
    }

    var monthlyAILimit: Int {
        switch self {
        case .free: 200
        case .pro: 10_000
        case .team: 50_000
        }
    }

    var includesAIChat: Bool { self != .free }
    var includesCloudSync: Bool { self != .free }
    var includesAdvancedGraph: Bool { self != .free }
    var includesTeamFeatures: Bool { self == .team }
}

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var title: String
    var collectionName: String
    var createdAt: Date
    var updatedAt: Date
    var lastOpenedAt: Date
    var isPinned: Bool
    var isArchived: Bool
    var isAIEligible: Bool
    var isDailyNote: Bool
    var dailyDate: Date?
    var tags: [String]
    var aiOrganizationCount: Int

    @Relationship(deleteRule: .cascade) var content: NoteContent?
    @Relationship(deleteRule: .cascade) var aiMetadata: NoteAIMetadata?
    @Relationship(deleteRule: .cascade) var embeddings: [NoteEmbedding]

    init(
        id: UUID = UUID(),
        title: String,
        markdown: String,
        collectionName: String = "Unorganized",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        tags: [String] = [],
        isAIEligible: Bool = true,
        isDailyNote: Bool = false,
        dailyDate: Date? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.collectionName = collectionName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = updatedAt
        self.isPinned = isPinned
        self.isArchived = false
        self.isAIEligible = isAIEligible
        self.isDailyNote = isDailyNote
        self.dailyDate = dailyDate.map { Calendar.current.startOfDay(for: $0) }
        self.tags = tags
        self.aiOrganizationCount = 0
        self.content = NoteContent(noteID: id, markdown: markdown)
        self.aiMetadata = NoteAIMetadata(noteID: id)
        self.embeddings = []
    }

    var markdown: String {
        content?.markdown ?? ""
    }

    var excerpt: String {
        markdown
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .split(separator: "\n")
            .prefix(3)
            .joined(separator: " ")
    }
}

@Model
final class NoteContent {
    @Attribute(.unique) var id: UUID
    var noteID: UUID
    @Attribute(.externalStorage) var markdown: String
    var wordCount: Int
    var characterCount: Int
    var updatedAt: Date

    init(id: UUID = UUID(), noteID: UUID, markdown: String, updatedAt: Date = .now) {
        self.id = id
        self.noteID = noteID
        self.markdown = markdown
        self.wordCount = markdown.split { $0.isWhitespace || $0.isNewline }.count
        self.characterCount = markdown.count
        self.updatedAt = updatedAt
    }

    func updateMarkdown(_ markdown: String, at date: Date = .now) {
        self.markdown = markdown
        self.wordCount = markdown.split { $0.isWhitespace || $0.isNewline }.count
        self.characterCount = markdown.count
        self.updatedAt = date
    }
}

@Model
final class Tag {
    @Attribute(.unique) var name: String
    var colorHex: String
    var createdAt: Date
    var usageCount: Int

    init(name: String, colorHex: String = "#3AB7A8", createdAt: Date = .now, usageCount: Int = 0) {
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.usageCount = usageCount
    }
}

@Model
final class NoteCollection {
    @Attribute(.unique) var name: String
    var summary: String
    var iconName: String
    var createdAt: Date
    var sortOrder: Int

    init(name: String, summary: String = "", iconName: String = "folder", createdAt: Date = .now, sortOrder: Int = 0) {
        self.name = name
        self.summary = summary
        self.iconName = iconName
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}

@Model
final class NoteLink {
    @Attribute(.unique) var id: UUID
    var sourceNoteID: UUID
    var targetNoteID: UUID?
    var rawTarget: String
    var displayText: String
    var kindRaw: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sourceNoteID: UUID,
        targetNoteID: UUID?,
        rawTarget: String,
        displayText: String,
        kind: LinkKind,
        createdAt: Date = .now
    ) {
        self.id = id
        self.sourceNoteID = sourceNoteID
        self.targetNoteID = targetNoteID
        self.rawTarget = rawTarget
        self.displayText = displayText
        self.kindRaw = kind.rawValue
        self.createdAt = createdAt
    }

    var kind: LinkKind {
        get { LinkKind(rawValue: kindRaw) ?? .wiki }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
final class GraphEdge {
    @Attribute(.unique) var id: UUID
    var sourceNoteID: UUID
    var targetNoteID: UUID
    var kindRaw: String
    var weight: Double
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sourceNoteID: UUID,
        targetNoteID: UUID,
        kind: LinkKind,
        weight: Double = 1,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.sourceNoteID = sourceNoteID
        self.targetNoteID = targetNoteID
        self.kindRaw = kind.rawValue
        self.weight = weight
        self.updatedAt = updatedAt
    }

    var kind: LinkKind {
        get { LinkKind(rawValue: kindRaw) ?? .wiki }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
final class NoteAIMetadata {
    @Attribute(.unique) var id: UUID
    var noteID: UUID
    var summary: String
    var suggestedTitle: String
    var suggestedTags: [String]
    var suggestedCollection: String
    var relatedNoteIDs: [UUID]
    var unresolvedLinkTargets: [String]
    var lastOrganizedAt: Date?
    var suggestionStatus: String
    var lastErrorMessage: String?

    init(
        id: UUID = UUID(),
        noteID: UUID,
        summary: String = "",
        suggestedTitle: String = "",
        suggestedTags: [String] = [],
        suggestedCollection: String = "",
        relatedNoteIDs: [UUID] = [],
        unresolvedLinkTargets: [String] = [],
        lastOrganizedAt: Date? = nil,
        suggestionStatus: String = "draft",
        lastErrorMessage: String? = nil
    ) {
        self.id = id
        self.noteID = noteID
        self.summary = summary
        self.suggestedTitle = suggestedTitle
        self.suggestedTags = suggestedTags
        self.suggestedCollection = suggestedCollection
        self.relatedNoteIDs = relatedNoteIDs
        self.unresolvedLinkTargets = unresolvedLinkTargets
        self.lastOrganizedAt = lastOrganizedAt
        self.suggestionStatus = suggestionStatus
        self.lastErrorMessage = lastErrorMessage
    }
}

@Model
final class AIJob {
    @Attribute(.unique) var id: UUID
    var noteID: UUID
    var statusRaw: String
    var requestedAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var errorMessage: String?

    init(id: UUID = UUID(), noteID: UUID, status: AIJobStatus = .queued, requestedAt: Date = .now) {
        self.id = id
        self.noteID = noteID
        self.statusRaw = status.rawValue
        self.requestedAt = requestedAt
        self.startedAt = nil
        self.completedAt = nil
        self.errorMessage = nil
    }

    var status: AIJobStatus {
        get { AIJobStatus(rawValue: statusRaw) ?? .queued }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class NoteEmbedding {
    @Attribute(.unique) var id: UUID
    var noteID: UUID
    var modelIdentifier: String
    var vector: [Double]
    var sourceHash: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        noteID: UUID,
        modelIdentifier: String,
        vector: [Double],
        sourceHash: String,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.noteID = noteID
        self.modelIdentifier = modelIdentifier
        self.vector = vector
        self.sourceHash = sourceHash
        self.updatedAt = updatedAt
    }
}

@Model
final class SubscriptionEntitlement {
    @Attribute(.unique) var id: UUID
    var planRaw: String
    var monthlyAIUsage: Int
    var aiCreditBalance: Int
    var storageLimitGB: Int
    var renewsAt: Date?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        plan: SubscriptionPlan = .free,
        monthlyAIUsage: Int = 0,
        aiCreditBalance: Int = 0,
        storageLimitGB: Int = 5,
        renewsAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.planRaw = plan.rawValue
        self.monthlyAIUsage = monthlyAIUsage
        self.aiCreditBalance = aiCreditBalance
        self.storageLimitGB = storageLimitGB
        self.renewsAt = renewsAt
        self.updatedAt = updatedAt
    }

    var plan: SubscriptionPlan {
        get { SubscriptionPlan(rawValue: planRaw) ?? .free }
        set { planRaw = newValue.rawValue }
    }

    var remainingAIOrganizeCount: Int {
        max(0, plan.monthlyAILimit + aiCreditBalance - monthlyAIUsage)
    }
}
