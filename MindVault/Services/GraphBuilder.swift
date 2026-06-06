import CoreGraphics
import Foundation

enum GraphBuilder {
    static func build(notes: [Note], links: [NoteLink], aiEdges: [GraphEdge]) -> KnowledgeGraph {
        let noteByID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        var graphLinks: [GraphLink] = []

        for link in links {
            guard let targetID = link.targetNoteID, noteByID[link.sourceNoteID] != nil, noteByID[targetID] != nil else {
                continue
            }
            graphLinks.append(GraphLink(id: link.id, sourceID: link.sourceNoteID, targetID: targetID, kind: link.kind, weight: 1))
        }

        graphLinks.append(
            contentsOf: aiEdges
                .filter { noteByID[$0.sourceNoteID] != nil && noteByID[$0.targetNoteID] != nil }
                .map { GraphLink(id: $0.id, sourceID: $0.sourceNoteID, targetID: $0.targetNoteID, kind: $0.kind, weight: $0.weight) }
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
                        weight: Double(sharedTags.count) * 0.35
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
