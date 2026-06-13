import CoreGraphics
import Foundation

enum GraphBuilder {
    static func build(notes: [Note], links: [NoteLink], aiEdges: [GraphEdge]) -> KnowledgeGraph {
        let noteByID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        var graphLinks: [GraphLink] = []

        for link in links {
            guard let targetID = link.targetNoteID,
                  let sourceNote = noteByID[link.sourceNoteID],
                  let targetNote = noteByID[targetID]
            else {
                continue
            }
            graphLinks.append(
                GraphLink(
                    id: link.id,
                    sourceID: link.sourceNoteID,
                    targetID: targetID,
                    kind: link.kind,
                    weight: 1,
                    reason: explicitLinkReason(link: link, sourceNote: sourceNote, targetNote: targetNote)
                )
            )
        }

        graphLinks.append(
            contentsOf: aiEdges
                .compactMap { edge in
                    guard let sourceNote = noteByID[edge.sourceNoteID], let targetNote = noteByID[edge.targetNoteID] else {
                        return nil
                    }
                    return GraphLink(
                        id: edge.id,
                        sourceID: edge.sourceNoteID,
                        targetID: edge.targetNoteID,
                        kind: edge.kind,
                        weight: edge.weight,
                        reason: aiLinkReason(edge: edge, sourceNote: sourceNote, targetNote: targetNote)
                    )
                }
        )

        graphLinks.append(contentsOf: tagCooccurrenceLinks(notes: notes))

        let degreeByID = graphLinks.reduce(into: [UUID: Int]()) { result, link in
            result[link.sourceID, default: 0] += 1
            result[link.targetID, default: 0] += 1
        }

        let sortedNotes = notes.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }

        let nodes = sortedNotes.enumerated().map { index, note in
            GraphNode(
                id: note.id,
                title: note.title,
                tags: note.tags,
                collectionName: note.collectionName,
                weight: Double(max(1, degreeByID[note.id, default: 1])),
                position: position(for: index, count: max(sortedNotes.count, 1), degree: degreeByID[note.id, default: 1]),
                isAIEligible: note.isAIEligible
            )
        }

        return KnowledgeGraph(nodes: nodes, links: graphLinks)
    }

    private static func position(for index: Int, count: Int, degree: Int) -> CGPoint {
        if index == 0 {
            return CGPoint(x: 0, y: 0)
        }
        let angle = Double(index) / Double(count) * .pi * 2
        let ring = 150 + Double(index % 4) * 58 - Double(min(degree, 6)) * 8
        return CGPoint(x: cos(angle) * ring, y: sin(angle) * ring)
    }

    private static func tagCooccurrenceLinks(notes: [Note]) -> [GraphLink] {
        var links: [GraphLink] = []
        for sourceIndex in notes.indices {
            for targetIndex in notes.indices where targetIndex > sourceIndex {
                let sharedTags = significantSharedTags(between: notes[sourceIndex], and: notes[targetIndex])
                guard !sharedTags.isEmpty else { continue }
                links.append(
                    GraphLink(
                        id: tagCooccurrenceLinkID(
                            sourceID: notes[sourceIndex].id,
                            targetID: notes[targetIndex].id
                        ),
                        sourceID: notes[sourceIndex].id,
                        targetID: notes[targetIndex].id,
                        kind: .tagCooccurrence,
                        weight: Double(sharedTags.count) * 0.35,
                        reason: sharedTagReason(
                            tags: sharedTags,
                            sourceNote: notes[sourceIndex],
                            targetNote: notes[targetIndex]
                        )
                    )
                )
            }
        }
        return links
    }

    private static func significantSharedTags(between first: Note, and second: Note) -> Set<String> {
        Set(first.tags)
            .intersection(second.tags)
            .filter { !genericTagNames.contains($0) }
    }

    private static func explicitLinkReason(link: NoteLink, sourceNote: Note, targetNote: Note) -> GraphConnectionReason {
        switch link.kind {
        case .wiki:
            return GraphConnectionReason(
                summary: "Explicit wiki link",
                evidence: "\(sourceNote.title) links to [[\(link.rawTarget.isEmpty ? targetNote.title : link.rawTarget)]].",
                confidence: 1,
                source: .explicitWikiLink
            )
        case .markdown:
            let label = link.displayText.isEmpty ? targetNote.title : link.displayText
            return GraphConnectionReason(
                summary: "Explicit Markdown link",
                evidence: "\(sourceNote.title) links with [\(label)](\(link.rawTarget)).",
                confidence: 1,
                source: .explicitMarkdownLink
            )
        case .aiRelated:
            return aiLinkReason(weight: 0.72, sourceNote: sourceNote, targetNote: targetNote)
        case .tagCooccurrence:
            return sharedTagReason(
                tags: significantSharedTags(between: sourceNote, and: targetNote),
                sourceNote: sourceNote,
                targetNote: targetNote
            )
        }
    }

    private static func aiLinkReason(edge: GraphEdge, sourceNote: Note, targetNote: Note) -> GraphConnectionReason {
        aiLinkReason(weight: edge.weight, sourceNote: sourceNote, targetNote: targetNote)
    }

    private static func aiLinkReason(weight: Double, sourceNote: Note, targetNote: Note) -> GraphConnectionReason {
        let metadata = sourceNote.aiMetadata
        let summary = metadata?.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let acceptedByMetadata = metadata?.relatedNoteIDs.contains(targetNote.id) == true
        let evidence: String
        if let summary, !summary.isEmpty {
            evidence = "\(sourceNote.title) AI summary: \(summary)"
        } else if acceptedByMetadata {
            evidence = "\(sourceNote.title) AI organization lists \(targetNote.title) as a related note."
        } else {
            evidence = "Stored AI relationship edge between \(sourceNote.title) and \(targetNote.title)."
        }

        return GraphConnectionReason(
            summary: acceptedByMetadata ? "AI suggested related note" : "AI relationship edge",
            evidence: evidence,
            confidence: min(max(weight, 0.01), 1),
            source: .aiSuggestion
        )
    }

    private static func sharedTagReason(tags: Set<String>, sourceNote: Note, targetNote: Note) -> GraphConnectionReason {
        let sortedTags = tags.sorted { $0.localizedCompare($1) == .orderedAscending }
        let tagList = sortedTags.isEmpty ? "no significant shared tags" : sortedTags.joined(separator: ", ")
        return GraphConnectionReason(
            summary: "Shared meaningful tags",
            evidence: "\(sourceNote.title) and \(targetNote.title) share: \(tagList).",
            confidence: min(max(Double(sortedTags.count) * 0.35, 0.01), 1),
            source: .sharedTags
        )
    }

    private static let genericTagNames: Set<String> = [
        "GettingStarted",
        "Guide",
        "Unorganized",
        "Journal",
        "AI",
        "Markdown",
        "Graph",
        "Search",
        "Review",
        "はじめに",
        "使い方",
        "未整理",
        "日記",
        "AI活用",
        "Markdown",
        "グラフ",
        "検索",
        "レビュー"
    ]

    private static func tagCooccurrenceLinkID(sourceID: UUID, targetID: UUID) -> UUID {
        let orderedIDs = [sourceID.uuidString, targetID.uuidString].sorted()
        let seed = "\(orderedIDs[0])|\(orderedIDs[1])|\(LinkKind.tagCooccurrence.rawValue)"
        var primary: UInt64 = 0xcbf29ce484222325
        var secondary: UInt64 = 0x84222325cbf29ce4

        for byte in seed.utf8 {
            primary ^= UInt64(byte)
            primary = primary &* 0x100000001b3
            secondary = (secondary &+ UInt64(byte)) &* 0x9e3779b185ebca87
        }

        var bytes: [UInt8] = []
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8((primary >> UInt64(shift)) & 0xff))
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8((secondary >> UInt64(shift)) & 0xff))
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
