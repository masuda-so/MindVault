import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable(description: "A concise organization draft for one personal knowledge note.")
struct FoundationOrganizationPayload {
    @Guide(description: "A short title in the note's language, no longer than 28 characters.")
    var suggestedTitle: String

    @Guide(description: "A two sentence summary in the note's language.")
    var summary: String

    @Guide(description: "Three to six short tags in the note's language without hash marks.")
    var suggestedTags: [String]

    @Guide(description: "Titles of existing notes that are likely related.")
    var relatedNoteTitles: [String]

    @Guide(description: "A concise collection name such as Product, Marketing, Personal Learning, Journal, or Unorganized.")
    var suggestedCollection: String

    @Guide(description: "Potential wiki-link targets that are mentioned but not yet linked.")
    var unresolvedLinks: [String]
}
#endif

enum AIAvailabilityState: Equatable {
    case available
    case unavailable(String)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .available:
            String(localized: "On-device AI is available")
        case .unavailable(let reason):
            reason
        }
    }
}

@MainActor
protocol NoteOrganizing {
    func availability() -> AIAvailabilityState
    func organize(_ request: NoteOrganizationRequest) async throws -> NoteOrganizationSuggestion
    func answer(question: String, notes: [Note]) async throws -> ChatAnswer
}

final class FoundationModelOrganizer: NoteOrganizing {
    func availability() -> AIAvailabilityState {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return .available
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable(String(localized: "On-device AI is unavailable because Apple Intelligence is not enabled."))
            case .unavailable(.deviceNotEligible):
                return .unavailable(String(localized: "This device does not support Foundation Models."))
            case .unavailable(.modelNotReady):
                return .unavailable(String(localized: "The Foundation Models model is not ready yet."))
            @unknown default:
                return .unavailable(String(localized: "The Foundation Models status could not be checked."))
            }
        }
        #endif
        return .unavailable(String(localized: "Foundation Models are unavailable in this runtime environment."))
    }

    func organize(_ request: NoteOrganizationRequest) async throws -> NoteOrganizationSuggestion {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), availability().isAvailable {
            let session = LanguageModelSession(
                model: SystemLanguageModel(useCase: .contentTagging),
                instructions: """
                You organize private user notes on device. Never invent facts. Return concise metadata in the same language as the note for MindVault AI.
                Prefer tags and collections that help Obsidian-style knowledge retrieval.
                """
            )
            let candidates = request.candidateNotes.prefix(12).joined(separator: ", ")
            let prompt = """
            Note title: \(request.title)
            Existing tags: \(request.existingTags.joined(separator: ", "))
            Existing note titles: \(candidates)

            Markdown:
            \(request.markdown.prefix(5_000))
            """
            let response = try await session.respond(
                to: prompt,
                generating: FoundationOrganizationPayload.self,
                options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 700)
            )
            return NoteOrganizationSuggestion(
                suggestedTitle: response.content.suggestedTitle,
                summary: response.content.summary,
                suggestedTags: response.content.suggestedTags.cleanedTags,
                relatedNoteTitles: response.content.relatedNoteTitles,
                suggestedCollection: response.content.suggestedCollection,
                unresolvedLinks: response.content.unresolvedLinks
            )
        }
        #endif
        throw NSError(
            domain: "MindVault.FoundationModels",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: availability().message]
        )
    }

    func answer(question: String, notes: [Note]) async throws -> ChatAnswer {
        let rankedNotes = EmbeddingSearchService.rank(query: question, notes: notes, limit: 5).map(\.note)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), availability().isAvailable {
            let context = rankedNotes.map { note in
                """
                [\(note.title)]
                Tags: \(note.tags.joined(separator: ", "))
                \(note.markdown.prefix(1_500))
                """
            }.joined(separator: "\n\n---\n\n")
            let session = LanguageModelSession(
                model: SystemLanguageModel(useCase: .general),
                instructions: "Answer using only the supplied local notes. Cite note titles and respond in the same language as the question."
            )
            let response = try await session.respond(
                to: """
                Question: \(question)

                Local notes:
                \(context)
                """,
                options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 900)
            )
            return ChatAnswer(question: question, answer: response.content, sourceNoteIDs: rankedNotes.map(\.id))
        }
        #endif
        throw NSError(
            domain: "MindVault.FoundationModels",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: availability().message]
        )
    }
}

extension Array where Element == String {
    var cleanedTags: [String] {
        Array(
            Set(
                map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "# \n\t")) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted { $0.localizedCompare($1) == .orderedAscending }
    }
}
