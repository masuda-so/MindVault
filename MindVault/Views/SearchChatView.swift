import SwiftUI

struct SearchChatView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AIJobQueue.self) private var aiQueue

    let notes: [Note]
    let entitlement: SubscriptionEntitlement?
    @Binding var selectedNoteID: UUID?
    @Binding var mode: WorkspaceMode
    var onOpenNote: (() -> Void)? = nil

    @State private var question = String(localized: "How do I use AI organization?")
    @State private var answer: ChatAnswer?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var rankedNotes: [(note: Note, score: Double)] {
        EmbeddingSearchService.rank(query: question, notes: notes, limit: 5)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header

                VStack(alignment: .leading, spacing: 10) {
                    TextField("AI Chat Search", text: $question, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)

                    Button {
                        runSearch()
                    } label: {
                        Label("Search", systemImage: "sparkle.magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.mint)
                    .disabled(!canRunAIChat)
                    .frame(maxWidth: horizontalSizeClass == .compact ? .infinity : nil, alignment: .trailing)
                }

                if let answer {
                    VaultPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(answer.answer)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                            Divider()
                            Text("Referenced Notes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(notes.filter { answer.sourceNoteIDs.contains($0.id) }) { note in
                                Button {
                                    open(note)
                                } label: {
                                    Label(note.title, systemImage: "doc.text")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else if let errorMessage {
                    VaultPanel {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                    }
                }

                VaultPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Vector Search Candidates")
                            .font(.headline)
                        ForEach(rankedNotes, id: \.note.id) { result in
                            Button {
                                open(result.note)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(result.note.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(result.note.excerpt)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Text(result.score, format: .number.precision(.fractionLength(2)))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaPadding(.bottom, 16)
        .navigationTitle("AI Chat Search")
    }

    private var header: some View {
        VaultPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Ask using local notes only")
                        .font(.title3.weight(.semibold))
                    Spacer(minLength: 8)
                    PlanBadge(plan: entitlement?.plan ?? .free)
                }
                Text("Related candidates are selected with local Natural Language embeddings. Answers are generated only when Foundation Models are available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var canRunAIChat: Bool {
        (entitlement?.plan.includesAIChat ?? false) && aiQueue.availability.isAvailable && !isLoading
    }

    private func runSearch() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                answer = try await aiQueue.answer(question: question, notes: notes)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func open(_ note: Note) {
        selectedNoteID = note.id
        if let onOpenNote {
            onOpenNote()
        } else {
            mode = .editor
        }
    }
}
