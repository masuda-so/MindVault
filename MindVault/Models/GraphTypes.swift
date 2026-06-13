import CoreGraphics
import Foundation

struct MarkdownLink: Hashable, Sendable {
    var title: String
    var destination: String
}

struct MarkdownIndex: Equatable, Sendable {
    var tags: [String]
    var wikiLinks: [String]
    var markdownLinks: [MarkdownLink]
    var headings: [String]

    static let empty = MarkdownIndex(tags: [], wikiLinks: [], markdownLinks: [], headings: [])
}

struct NoteOrganizationRequest: Sendable {
    var noteID: UUID
    var title: String
    var markdown: String
    var existingTags: [String]
    var candidateNotes: [String]
}

struct NoteOrganizationSuggestion: Equatable, Sendable {
    var suggestedTitle: String
    var summary: String
    var suggestedTags: [String]
    var relatedNoteTitles: [String]
    var suggestedCollection: String
    var unresolvedLinks: [String]
}

struct GraphNode: Identifiable, Hashable {
    var id: UUID
    var title: String
    var tags: [String]
    var collectionName: String
    var weight: Double
    var position: CGPoint
    var isAIEligible: Bool
}

struct GraphLink: Identifiable, Hashable {
    var id: UUID
    var sourceID: UUID
    var targetID: UUID
    var kind: LinkKind
    var weight: Double
    var reason: GraphConnectionReason
}

struct GraphConnectionReason: Hashable {
    var summary: String
    var evidence: String
    var confidence: Double
    var source: GraphConnectionReasonSource

    var isEvaluationReady: Bool {
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && confidence > 0
    }
}

enum GraphConnectionReasonSource: String, Hashable {
    case explicitWikiLink
    case explicitMarkdownLink
    case aiSuggestion
    case sharedTags
}

struct KnowledgeGraph: Equatable {
    var nodes: [GraphNode]
    var links: [GraphLink]

    static let empty = KnowledgeGraph(nodes: [], links: [])
}

struct ChatAnswer: Identifiable, Equatable {
    var id = UUID()
    var question: String
    var answer: String
    var sourceNoteIDs: [UUID]
}
