import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AIJobQueue {
    private let organizer: NoteOrganizing
    private(set) var availability: AIAvailabilityState
    private(set) var runningNoteIDs: Set<UUID> = []

    convenience init() {
        self.init(organizer: FoundationModelOrganizer())
    }

    init(organizer: NoteOrganizing) {
        self.organizer = organizer
        self.availability = organizer.availability()
    }

    func refreshAvailability() {
        availability = organizer.availability()
    }

    func enqueueOrganization(note: Note, allNotes: [Note], entitlement: SubscriptionEntitlement?, context: ModelContext) {
        guard note.isAIEligible else {
            markSkipped(note: note, message: String(localized: "This note is excluded from AI processing."), context: context)
            return
        }
        guard availability.isAvailable else {
            recordOrganizationError(availability.message, for: note, context: context)
            return
        }
        guard let entitlement, entitlement.remainingAIOrganizeCount > 0 else {
            recordOrganizationError(String(localized: "The Free plan monthly AI organization limit has been reached."), for: note, context: context)
            return
        }
        guard !runningNoteIDs.contains(note.id) else { return }

        let job = AIJob(noteID: note.id)
        context.insert(job)
        runningNoteIDs.insert(note.id)

        Task {
            await runOrganization(job: job, note: note, allNotes: allNotes, entitlement: entitlement, context: context)
        }
    }

    func runOrganization(job: AIJob, note: Note, allNotes: [Note], entitlement: SubscriptionEntitlement, context: ModelContext) async {
        defer {
            runningNoteIDs.remove(note.id)
        }

        job.status = .running
        job.startedAt = .now

        let eligibleCandidateNotes = allNotes.filter { candidate in
            candidate.id != note.id && candidate.isAIEligible
        }

        let request = NoteOrganizationRequest(
            noteID: note.id,
            title: note.title,
            markdown: note.markdown,
            existingTags: note.tags,
            candidateNotes: eligibleCandidateNotes.map(\.title)
        )

        do {
            let suggestion = try await organizer.organize(request)
            applyDraftSuggestion(suggestion, to: note, allNotes: allNotes, context: context)
            entitlement.monthlyAIUsage += 1
            entitlement.updatedAt = .now
            note.aiOrganizationCount += 1
            job.status = .completed
            job.completedAt = .now
        } catch {
            job.status = .failed
            job.errorMessage = error.localizedDescription
            note.aiMetadata?.lastErrorMessage = error.localizedDescription
            try? context.save()
        }
    }

    func answer(question: String, notes: [Note]) async throws -> ChatAnswer {
        guard availability.isAvailable else {
            throw NSError(domain: "MindVault.AIChat", code: 1, userInfo: [NSLocalizedDescriptionKey: availability.message])
        }
        return try await organizer.answer(question: question, notes: notes.filter(\.isAIEligible))
    }

    func applyAcceptedSuggestion(to note: Note, context: ModelContext) {
        guard let metadata = note.aiMetadata else { return }
        if !metadata.suggestedTitle.isEmpty {
            note.title = metadata.suggestedTitle
        }
        if !metadata.suggestedCollection.isEmpty {
            note.collectionName = metadata.suggestedCollection
        }
        note.tags = Array(Set(note.tags + metadata.suggestedTags)).sorted { $0.localizedCompare($1) == .orderedAscending }
        metadata.suggestionStatus = "accepted"
        note.updatedAt = .now
        try? context.save()
    }

    func dismissSuggestion(for note: Note, context: ModelContext) {
        note.aiMetadata?.suggestionStatus = "dismissed"
        try? context.save()
    }

    private func applyDraftSuggestion(
        _ suggestion: NoteOrganizationSuggestion,
        to note: Note,
        allNotes: [Note],
        context: ModelContext
    ) {
        let metadata = note.aiMetadata ?? NoteAIMetadata(noteID: note.id)
        if note.aiMetadata == nil {
            note.aiMetadata = metadata
        }
        metadata.suggestedTitle = suggestion.suggestedTitle
        metadata.summary = suggestion.summary
        metadata.suggestedTags = suggestion.suggestedTags
        metadata.suggestedCollection = suggestion.suggestedCollection
        metadata.unresolvedLinkTargets = suggestion.unresolvedLinks
        metadata.relatedNoteIDs = relatedIDs(from: suggestion.relatedNoteTitles, allNotes: allNotes)
        metadata.lastOrganizedAt = .now
        metadata.suggestionStatus = "draft"
        metadata.lastErrorMessage = nil

        upsertRelatedEdges(sourceNoteID: note.id, relatedIDs: metadata.relatedNoteIDs, context: context)
        try? context.save()
    }

    private func markSkipped(note: Note, message: String, context: ModelContext) {
        let job = AIJob(noteID: note.id, status: .skipped)
        job.errorMessage = message
        job.completedAt = .now
        context.insert(job)
        note.aiMetadata?.lastErrorMessage = message
        try? context.save()
    }

    private func relatedIDs(from titles: [String], allNotes: [Note]) -> [UUID] {
        let titleMap = allNotes.filter(\.isAIEligible).reduce(into: [String: UUID]()) { result, note in
            result[note.title.normalizedLinkTarget, default: note.id] = note.id
        }
        return titles.compactMap { titleMap[$0.normalizedLinkTarget] }
    }

    private func recordOrganizationError(_ message: String, for note: Note, context: ModelContext) {
        note.aiMetadata?.lastErrorMessage = message
        try? context.save()
    }

    private func upsertRelatedEdges(sourceNoteID: UUID, relatedIDs: [UUID], context: ModelContext) {
        let aiRelatedKind = LinkKind.aiRelated.rawValue
        let descriptor = FetchDescriptor<GraphEdge>(predicate: #Predicate { edge in
            edge.sourceNoteID == sourceNoteID && edge.kindRaw == aiRelatedKind
        })
        if let existing = try? context.fetch(descriptor) {
            existing.forEach(context.delete)
        }
        for relatedID in relatedIDs where relatedID != sourceNoteID {
            context.insert(GraphEdge(sourceNoteID: sourceNoteID, targetNoteID: relatedID, kind: .aiRelated, weight: 0.72))
        }
    }
}
