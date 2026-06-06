import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum ImportExportService {
    static let maximumImportFileSizeBytes = 2_000_000
    static let maximumImportedNoteCount = 500

    static func exportMarkdown(note: Note) -> String {
        let frontmatter = """
        ---
        id: \(note.id.uuidString)
        title: \(yamlQuoted(note.title))
        collection: \(yamlQuoted(note.collectionName))
        tags: [\(note.tags.map(yamlQuoted).joined(separator: ", "))]
        aiEligible: \(note.isAIEligible)
        updatedAt: \(yamlQuoted(note.updatedAt.ISO8601Format()))
        ---

        """
        return frontmatter + note.markdown
    }

    static func exportJSON(notes: [Note]) throws -> Data {
        let payload = notes.map { note in
            ExportedNote(
                id: note.id,
                title: note.title,
                markdown: note.markdown,
                collectionName: note.collectionName,
                tags: note.tags,
                isAIEligible: note.isAIEligible,
                createdAt: note.createdAt,
                updatedAt: note.updatedAt,
                summary: note.aiMetadata?.summary ?? ""
            )
        }
        return try JSONEncoder.mindVault.encode(payload)
    }

    static func exportCSV(notes: [Note]) -> String {
        let header = "id,title,collection,tags,aiEligible,updatedAt,markdown,summary"
        let rows = notes.map { note in
            [
                note.id.uuidString,
                note.title,
                note.collectionName,
                note.tags.joined(separator: "|"),
                String(note.isAIEligible),
                note.updatedAt.ISO8601Format(),
                note.markdown,
                note.aiMetadata?.summary ?? ""
            ]
            .map(csvEscape)
            .joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    static func parseMarkdownImport(filename: String, markdown: String) -> Note {
        let parsedFrontmatter = parseFrontmatter(markdown)
        let body = parsedFrontmatter?.body ?? markdown
        let frontmatter = parsedFrontmatter?.values ?? [:]
        let firstHeading = body
            .split(separator: "\n")
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "# ")) }
        let title = frontmatter["title"] ?? firstHeading ?? filename.replacingOccurrences(of: ".md", with: "")
        let index = MarkdownIndexingService.parse(body)
        let frontmatterTags = tagsFromFrontmatter(frontmatter["tags"])
        let tags = Array(Set(frontmatterTags + index.tags)).sorted { $0.localizedCompare($1) == .orderedAscending }
        let updatedAt = frontmatter["updatedAt"].flatMap { ISO8601DateFormatter().date(from: $0) } ?? .now
        return Note(
            title: title,
            markdown: body,
            collectionName: frontmatter["collection"] ?? "Import",
            createdAt: updatedAt,
            updatedAt: updatedAt,
            tags: tags,
            isAIEligible: frontmatter["aiEligible"].flatMap(Bool.init) ?? true
        )
    }

    static func parseImport(filename: String, text: String) throws -> [Note] {
        let pathExtension = (filename as NSString).pathExtension.localizedLowercase
        let notes: [Note]
        switch pathExtension {
        case "json":
            let data = Data(text.utf8)
            let decoded = try JSONDecoder.mindVault.decode([ExportedNote].self, from: data)
            notes = decoded.map(makeNote(from:))
        case "csv":
            notes = parseCSV(text)
        default:
            notes = [parseMarkdownImport(filename: filename, markdown: text)]
        }
        try validateImportedNoteCount(notes.count)
        return notes
    }

    static func validateImportFileSize(_ byteCount: Int) throws {
        guard byteCount <= maximumImportFileSizeBytes else {
            throw ImportExportError.fileTooLarge(byteCount: byteCount, limit: maximumImportFileSizeBytes)
        }
    }

    private static func csvEscape(_ value: String) -> String {
        let protected = csvFormulaProtected(value)
        let escaped = protected.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func yamlQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }

    private static func csvFormulaProtected(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, ["=", "+", "-", "@"].contains(first) else {
            return value
        }
        return "'\(value)"
    }

    private static func makeNote(from exported: ExportedNote) -> Note {
        let note = Note(
            id: exported.id,
            title: exported.title,
            markdown: exported.markdown,
            collectionName: exported.collectionName,
            createdAt: exported.createdAt,
            updatedAt: exported.updatedAt,
            tags: exported.tags,
            isAIEligible: exported.isAIEligible
        )
        note.aiMetadata?.summary = exported.summary
        return note
    }

    private static func validateImportedNoteCount(_ count: Int) throws {
        guard count <= maximumImportedNoteCount else {
            throw ImportExportError.tooManyNotes(count: count, limit: maximumImportedNoteCount)
        }
    }

    private static func parseFrontmatter(_ markdown: String) -> (values: [String: String], body: String)? {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return nil
        }

        var values: [String: String] = [:]
        var closingIndex: Int?
        for index in lines.indices.dropFirst() {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                closingIndex = index
                break
            }
            guard let separatorIndex = line.firstIndex(of: ":") else { continue }
            let key = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = yamlUnquoted(String(rawValue))
        }

        guard let closingIndex else { return nil }
        let body = lines.dropFirst(closingIndex + 1).joined(separator: "\n")
        return (values, body)
    }

    private static func tagsFromFrontmatter(_ value: String?) -> [String] {
        guard let value else { return [] }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let regex = try? NSRegularExpression(pattern: #""((?:\\.|[^"])*)""#) else {
            return []
        }
        return regex.matches(in: value, range: range).compactMap { match in
            guard let tagRange = Range(match.range(at: 1), in: value) else { return nil }
            let tag = yamlUnescaped(String(value[tagRange])).trimmingCharacters(in: .whitespacesAndNewlines)
            return tag.isEmpty ? nil : tag
        }
    }

    private static func yamlUnquoted(_ value: String) -> String {
        guard value.first == "\"", value.last == "\"" else {
            return value
        }
        return yamlUnescaped(String(value.dropFirst().dropLast()))
    }

    private static func yamlUnescaped(_ value: String) -> String {
        var result = ""
        var isEscaped = false
        for character in value {
            if isEscaped {
                switch character {
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                default: result.append(character)
                }
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else {
                result.append(character)
            }
        }
        if isEscaped {
            result.append("\\")
        }
        return result
    }

    private static func parseCSV(_ text: String) -> [Note] {
        let rows = csvRows(in: text)
        guard rows.count > 1 else { return [] }
        let header = rows[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let columnByName = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })

        return rows.dropFirst().compactMap { row in
            guard row.count >= 7 else { return nil }
            let title = csvValue("title", in: row, columns: columnByName, fallbackIndex: 1)
            let collection = csvValue("collection", in: row, columns: columnByName, fallbackIndex: 2)
            let tags = csvValue("tags", in: row, columns: columnByName, fallbackIndex: 3)
                .split(separator: "|")
                .map(String.init)
                .filter { !$0.isEmpty }
            let updatedAt = ISO8601DateFormatter().date(
                from: csvValue("updatedAt", in: row, columns: columnByName, fallbackIndex: 5)
            ) ?? .now
            let summary = csvValue("summary", in: row, columns: columnByName, fallbackIndex: 6)
            let markdown = csvValue("markdown", in: row, columns: columnByName, fallbackIndex: nil)
            let note = Note(
                id: UUID(uuidString: csvValue("id", in: row, columns: columnByName, fallbackIndex: 0)) ?? UUID(),
                title: title,
                markdown: markdown.isEmpty ? "# \(title)\n\n\(summary)" : markdown,
                collectionName: collection.isEmpty ? "Import" : collection,
                createdAt: updatedAt,
                updatedAt: updatedAt,
                tags: tags,
                isAIEligible: Bool(csvValue("aiEligible", in: row, columns: columnByName, fallbackIndex: 4)) ?? true
            )
            note.aiMetadata?.summary = summary
            return note
        }
    }

    private static func csvValue(_ name: String, in row: [String], columns: [String: Int], fallbackIndex: Int?) -> String {
        if let index = columns[name], row.indices.contains(index) {
            return csvFormulaUnprotected(row[index])
        }
        if let fallbackIndex, row.indices.contains(fallbackIndex) {
            return csvFormulaUnprotected(row[fallbackIndex])
        }
        return ""
    }

    private static func csvFormulaUnprotected(_ value: String) -> String {
        guard value.first == "'", let second = value.dropFirst().first, ["=", "+", "-", "@"].contains(second) else {
            return value
        }
        return String(value.dropFirst())
    }

    private static func csvRows(in text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var iterator = text.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if isQuoted {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append(next)
                        } else {
                            isQuoted = false
                            if next == "," {
                                row.append(field)
                                field = ""
                            } else if next == "\n" {
                                row.append(field)
                                rows.append(row)
                                row = []
                                field = ""
                            } else {
                                field.append(next)
                            }
                        }
                    } else {
                        isQuoted = false
                    }
                } else {
                    isQuoted = true
                }
            } else if character == "," && !isQuoted {
                row.append(field)
                field = ""
            } else if character == "\n" && !isQuoted {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if character != "\r" {
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }
}

struct MindVaultExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .json, .commaSeparatedText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            text = string
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct ExportedNote: Codable, Equatable {
    var id: UUID
    var title: String
    var markdown: String
    var collectionName: String
    var tags: [String]
    var isAIEligible: Bool
    var createdAt: Date
    var updatedAt: Date
    var summary: String
}

enum ImportExportError: LocalizedError {
    case fileTooLarge(byteCount: Int, limit: Int)
    case tooManyNotes(count: Int, limit: Int)

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let byteCount, let limit):
            String(localized: "Import file is too large (\(byteCount) bytes / limit \(limit) bytes).")
        case .tooManyNotes(let count, let limit):
            String(localized: "You can import up to \(limit) notes at once (selected: \(count)).")
        }
    }
}

extension JSONEncoder {
    static var mindVault: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var mindVault: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
