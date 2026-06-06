import Foundation
import NaturalLanguage

enum EmbeddingSearchService {
    static let modelIdentifier = "NaturalLanguage.NLEmbedding.sentence.ja-en.local"

    static func embedding(for text: String) -> [Double] {
        let sample = String(text.prefix(1_500))
        if let japanese = NLEmbedding.sentenceEmbedding(for: .japanese),
           let vector = japanese.vector(for: sample) {
            return vector
        }
        if let english = NLEmbedding.sentenceEmbedding(for: .english),
           let vector = english.vector(for: sample) {
            return vector
        }
        return lexicalFallbackVector(for: sample)
    }

    static func rank(query: String, notes: [Note], limit: Int = 6) -> [(note: Note, score: Double)] {
        let queryVector = embedding(for: query)
        return notes
            .filter(\.isAIEligible)
            .map { note in
                let noteVector = note.embeddings.first?.vector ?? embedding(for: "\(note.title)\n\(note.markdown)")
                let score = cosineSimilarity(queryVector, noteVector) + keywordBoost(query: query, note: note)
                return (note, score)
            }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    static func upsertEmbedding(for note: Note) {
        guard note.isAIEligible else {
            note.embeddings.removeAll()
            return
        }
        let source = "\(note.title)\n\(note.markdown)"
        let hash = source.stableHash
        if let current = note.embeddings.first, current.sourceHash == hash {
            return
        }
        note.embeddings.removeAll()
        note.embeddings.append(
            NoteEmbedding(
                noteID: note.id,
                modelIdentifier: modelIdentifier,
                vector: embedding(for: source),
                sourceHash: hash
            )
        )
    }

    static func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard !lhs.isEmpty, lhs.count == rhs.count else { return 0 }
        let dot = zip(lhs, rhs).map(*).reduce(0, +)
        let leftMagnitude = sqrt(lhs.map { $0 * $0 }.reduce(0, +))
        let rightMagnitude = sqrt(rhs.map { $0 * $0 }.reduce(0, +))
        guard leftMagnitude > 0, rightMagnitude > 0 else { return 0 }
        return dot / (leftMagnitude * rightMagnitude)
    }

    private static func keywordBoost(query: String, note: Note) -> Double {
        let haystack = "\(note.title) \(note.tags.joined(separator: " ")) \(note.markdown)".localizedLowercase
        return query
            .localizedLowercase
            .split { $0.isWhitespace || $0.isPunctuation }
            .reduce(0) { partialResult, token in
                haystack.contains(token) ? partialResult + 0.12 : partialResult
            }
    }

    private static func lexicalFallbackVector(for text: String, dimensions: Int = 64) -> [Double] {
        var vector = Array(repeating: 0.0, count: dimensions)
        for token in text.localizedLowercase.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }) {
            let index = abs(String(token).stableHashValue) % dimensions
            vector[index] += 1
        }
        return vector
    }
}

extension String {
    var stableHash: String {
        String(stableHashValue, radix: 16)
    }

    var stableHashValue: Int {
        unicodeScalars.reduce(5381) { (($0 << 5) &+ $0) &+ Int($1.value) }
    }
}
