import Foundation
import SwiftData

enum MarkdownIndexingService {
    static func parse(_ markdown: String) -> MarkdownIndex {
        MarkdownIndex(
            tags: uniqueMatches(in: markdown, pattern: #"(?<![\p{L}\p{N}_-])#([\p{L}\p{N}_-]+)"#, captureGroup: 1),
            wikiLinks: uniqueMatches(in: markdown, pattern: #"\[\[([^\]|\n]+)(?:\|[^\]\n]+)?\]\]"#, captureGroup: 1),
            markdownLinks: markdownLinks(in: markdown),
            headings: headingLines(in: markdown)
        )
    }

    static func reindex(note: Note, allNotes: [Note], context: ModelContext) {
        let index = parse(note.markdown)
        note.tags = Array(Set(note.tags + index.tags)).sorted { $0.localizedCompare($1) == .orderedAscending }

        let noteID = note.id
        let descriptor = FetchDescriptor<NoteLink>(predicate: #Predicate { link in
            link.sourceNoteID == noteID
        })
        if let existingLinks = try? context.fetch(descriptor) {
            existingLinks.forEach(context.delete)
        }

        let targetByTitle = allNotes.reduce(into: [String: UUID]()) { result, note in
            result[note.title.normalizedLinkTarget, default: note.id] = note.id
        }
        for target in index.wikiLinks {
            let normalizedTarget = target.normalizedLinkTarget
            context.insert(
                NoteLink(
                    sourceNoteID: note.id,
                    targetNoteID: targetByTitle[normalizedTarget],
                    rawTarget: target,
                    displayText: target,
                    kind: .wiki
                )
            )
        }

        for markdownLink in index.markdownLinks {
            context.insert(
                NoteLink(
                    sourceNoteID: note.id,
                    targetNoteID: targetByTitle[markdownLink.destination.normalizedLinkTarget],
                    rawTarget: markdownLink.destination,
                    displayText: markdownLink.title,
                    kind: .markdown
                )
            )
        }

        ensureTags(index.tags, context: context)
        ensureCollection(note.collectionName, context: context)
    }

    static func backlinks(to note: Note, links: [NoteLink], notes: [Note]) -> [Note] {
        let sourceIDs = Set(links.filter { $0.targetNoteID == note.id }.map(\.sourceNoteID))
        return notes.filter { sourceIDs.contains($0.id) }
    }

    private static func uniqueMatches(in text: String, pattern: String, captureGroup: Int) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        let values = matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: captureGroup), in: text) else { return nil }
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return Array(NSOrderedSet(array: values)) as? [String] ?? []
    }

    private static func markdownLinks(in text: String) -> [MarkdownLink] {
        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]\n]+)\]\(([^\)\n]+)\)"#, options: []) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard
                let titleRange = Range(match.range(at: 1), in: text),
                let destinationRange = Range(match.range(at: 2), in: text)
            else { return nil }
            return MarkdownLink(title: String(text[titleRange]), destination: String(text[destinationRange]))
        }
    }

    private static func headingLines(in markdown: String) -> [String] {
        markdown
            .split(separator: "\n")
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.range(of: #"^#{1,6}\s+"#, options: .regularExpression) != nil else { return nil }
                return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            }
    }

    private static func ensureTags(_ tags: [String], context: ModelContext) {
        for tag in tags {
            let tagName = tag
            let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.name == tagName })
            let existing = (try? context.fetch(descriptor)) ?? []
            if existing.isEmpty {
                context.insert(Tag(name: tagName))
            } else {
                existing.first?.usageCount += 1
            }
        }
    }

    private static func ensureCollection(_ collectionName: String, context: ModelContext) {
        let descriptor = FetchDescriptor<NoteCollection>(predicate: #Predicate { $0.name == collectionName })
        if ((try? context.fetch(descriptor)) ?? []).isEmpty {
            context.insert(NoteCollection(name: collectionName, summary: String(localized: "AI-classified or user-created collection")))
        }
    }
}

extension String {
    var normalizedLinkTarget: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".md", with: "", options: [.caseInsensitive])
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
    }
}
