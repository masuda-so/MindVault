import SwiftData
import XCTest
@testable import MindVault

@MainActor
final class MindVaultCoreTests: XCTestCase {
    func testMarkdownParserExtractsTagsWikiLinksAndMarkdownLinks() {
        let markdown = """
        # 価格案
        [[収益モデルのメモ]] と [比較](競合サービス比較表.md) を確認。
        #価格戦略 #SaaS
        """

        let index = MarkdownIndexingService.parse(markdown)

        XCTAssertEqual(index.tags, ["価格戦略", "SaaS"])
        XCTAssertEqual(index.wikiLinks, ["収益モデルのメモ"])
        XCTAssertEqual(index.markdownLinks, [MarkdownLink(title: "比較", destination: "競合サービス比較表.md")])
        XCTAssertEqual(index.headings, ["価格案"])
    }

    func testReindexCreatesBacklinksAndRespectsTargets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let source = Note(title: "価格案", markdown: "[[収益モデルのメモ]]\n#SaaS", collectionName: "プロダクト")
        let target = Note(title: "収益モデルのメモ", markdown: "ProとTeamの収益。", collectionName: "プロダクト")
        context.insert(source)
        context.insert(target)

        MarkdownIndexingService.reindex(note: source, allNotes: [source, target], context: context)
        let links = try context.fetch(FetchDescriptor<NoteLink>())

        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.targetNoteID, target.id)
        XCTAssertEqual(source.tags, ["SaaS"])
        XCTAssertEqual(MarkdownIndexingService.backlinks(to: target, links: links, notes: [source, target]).map(\.id), [source.id])
    }

    func testGraphBuilderCreatesExplicitAndTagCooccurrenceEdges() {
        let first = Note(title: "価格案", markdown: "", collectionName: "プロダクト", tags: ["SaaS"])
        let second = Note(title: "収益モデル", markdown: "", collectionName: "プロダクト", tags: ["SaaS"])
        let wiki = NoteLink(sourceNoteID: first.id, targetNoteID: second.id, rawTarget: second.title, displayText: second.title, kind: .wiki)

        let graph = GraphBuilder.build(notes: [first, second], links: [wiki], aiEdges: [])

        XCTAssertEqual(graph.nodes.count, 2)
        XCTAssertTrue(graph.links.contains { $0.kind == .wiki })
        XCTAssertTrue(graph.links.contains { $0.kind == .tagCooccurrence })
    }

    func testGraphBuilderAddsEvaluationReadyConnectionReasons() {
        let first = Note(title: "価格案", markdown: "", collectionName: "プロダクト", tags: ["価格戦略", "SaaS"])
        let second = Note(title: "収益モデル", markdown: "", collectionName: "プロダクト", tags: ["価格戦略"])
        let wiki = NoteLink(sourceNoteID: first.id, targetNoteID: second.id, rawTarget: second.title, displayText: second.title, kind: .wiki)

        let graph = GraphBuilder.build(notes: [first, second], links: [wiki], aiEdges: [])
        let wikiReason = graph.links.first { $0.kind == .wiki }?.reason
        let tagReason = graph.links.first { $0.kind == .tagCooccurrence }?.reason

        XCTAssertEqual(wikiReason?.source, .explicitWikiLink)
        XCTAssertEqual(wikiReason?.confidence, 1)
        XCTAssertEqual(wikiReason?.isEvaluationReady, true)
        XCTAssertTrue(wikiReason?.evidence.contains("[[収益モデル]]") == true)
        XCTAssertEqual(tagReason?.source, .sharedTags)
        XCTAssertEqual(tagReason?.isEvaluationReady, true)
        XCTAssertTrue(tagReason?.evidence.contains("価格戦略") == true)
    }

    func testGraphBuilderUsesAISummaryAsConnectionEvidence() {
        let source = Note(title: "追加した価格メモ", markdown: "", collectionName: "未整理")
        let target = Note(title: "価格案とProプラン", markdown: "", collectionName: "プロダクト")
        source.aiMetadata?.summary = "価格と収益モデルを整理するメモです。"
        source.aiMetadata?.relatedNoteIDs = [target.id]
        let edge = GraphEdge(sourceNoteID: source.id, targetNoteID: target.id, kind: .aiRelated, weight: 0.72)

        let graph = GraphBuilder.build(notes: [source, target], links: [], aiEdges: [edge])
        let reason = graph.links.first?.reason

        XCTAssertEqual(reason?.source, .aiSuggestion)
        XCTAssertEqual(reason?.summary, "AI suggested related note")
        XCTAssertEqual(reason?.isEvaluationReady, true)
        XCTAssertTrue(reason?.evidence.contains("価格と収益モデル") == true)
        XCTAssertEqual(reason?.confidence, 0.72)
    }

    func testGraphBuilderIgnoresGenericTagsForCooccurrenceEdges() {
        let first = Note(title: "入口", markdown: "", collectionName: "使い方", tags: ["使い方"])
        let second = Note(title: "基本", markdown: "", collectionName: "使い方", tags: ["使い方"])

        let graph = GraphBuilder.build(notes: [first, second], links: [], aiEdges: [])

        XCTAssertFalse(graph.hasAnyLink(between: first, and: second, kind: .tagCooccurrence))
    }

    func testEmbeddingRankExcludesAIIneligibleNotes() {
        let publicNote = Note(title: "価格案とProプラン", markdown: "Pro価格とTeam価格の議論", tags: ["価格戦略"], isAIEligible: true)
        let privateNote = Note(title: "秘密の日記", markdown: "価格とは無関係", tags: ["日記"], isAIEligible: false)

        let ranked = EmbeddingSearchService.rank(query: "Pro価格", notes: [publicNote, privateNote])

        XCTAssertEqual(ranked.map(\.note.id), [publicNote.id])
    }

    func testImportExportRoundTripShapes() throws {
        let note = Note(title: "価格案", markdown: "# 価格案\n本文", collectionName: "プロダクト", tags: ["SaaS"])

        let markdown = ImportExportService.exportMarkdown(note: note)
        let json = try ImportExportService.exportJSON(notes: [note])
        let csv = ImportExportService.exportCSV(notes: [note])
        let imported = ImportExportService.parseMarkdownImport(filename: "価格案.md", markdown: markdown)
        let jsonImported = try ImportExportService.parseImport(filename: "notes.json", text: String(data: json, encoding: .utf8) ?? "[]")
        let csvImported = try ImportExportService.parseImport(filename: "notes.csv", text: csv)

        XCTAssertTrue(markdown.contains("aiEligible: true"))
        XCTAssertTrue(String(data: json, encoding: .utf8)?.contains("\"title\" : \"価格案\"") == true)
        XCTAssertTrue(csv.contains("\"価格案\""))
        XCTAssertEqual(imported.title, "価格案")
        XCTAssertEqual(jsonImported.first?.title, "価格案")
        XCTAssertEqual(csvImported.first?.title, "価格案")
    }

    func testCSVExportPreservesMarkdownAndNeutralizesFormulaCells() throws {
        let note = Note(
            title: "=HYPERLINK(\"https://example.com\")",
            markdown: "+SUM(1,1)",
            collectionName: "@Import",
            tags: ["CSV"]
        )

        let csv = ImportExportService.exportCSV(notes: [note])
        let imported = try ImportExportService.parseImport(filename: "notes.csv", text: csv)

        XCTAssertTrue(csv.contains("\"'=HYPERLINK(\"\"https://example.com\"\")\""))
        XCTAssertTrue(csv.contains("\"'+SUM(1,1)\""))
        XCTAssertEqual(imported.first?.title, note.title)
        XCTAssertEqual(imported.first?.markdown, note.markdown)
        XCTAssertEqual(imported.first?.collectionName, note.collectionName)
    }

    func testMarkdownImportReadsFrontmatterAndStripsItFromBody() {
        let markdown = """
        ---
        id: 8917A848-FE9F-45DF-87D5-DB9BF67F2B11
        title: "引用符\\\"つきメモ"
        collection: "インポート検証"
        tags: ["CSV", "安全"]
        aiEligible: false
        updatedAt: "2026-06-04T12:00:00Z"
        ---

        ## 本文見出し
        #本文タグ
        """

        let imported = ImportExportService.parseMarkdownImport(filename: "fallback.md", markdown: markdown)

        XCTAssertEqual(imported.title, "引用符\"つきメモ")
        XCTAssertEqual(imported.collectionName, "インポート検証")
        XCTAssertEqual(imported.tags, ["CSV", "安全", "本文タグ"])
        XCTAssertFalse(imported.isAIEligible)
        XCTAssertFalse(imported.markdown.contains("aiEligible"))
        XCTAssertTrue(imported.markdown.contains("## 本文見出し"))
    }

    func testReindexHandlesDuplicateNormalizedTitlesWithoutCrashing() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let source = Note(title: "入口", markdown: "[[重複メモ]]", collectionName: "テスト")
        let firstTarget = Note(title: "重複メモ", markdown: "first", collectionName: "テスト")
        let secondTarget = Note(title: "重複メモ.md", markdown: "second", collectionName: "テスト")
        [source, firstTarget, secondTarget].forEach(context.insert)

        MarkdownIndexingService.reindex(note: source, allNotes: [source, firstTarget, secondTarget], context: context)
        let links = try context.fetch(FetchDescriptor<NoteLink>())

        XCTAssertEqual(links.count, 1)
        XCTAssertNotNil(links.first?.targetNoteID)
    }

    func testAIJobQueueAppliesAndDismissesSuggestions() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let note = Note(title: "雑メモ", markdown: "Pro価格の議論", collectionName: "未整理", tags: [])
        let entitlement = SubscriptionEntitlement(plan: .pro, monthlyAIUsage: 0)
        context.insert(note)
        context.insert(entitlement)

        let queue = AIJobQueue(organizer: StubOrganizer())
        queue.enqueueOrganization(note: note, allNotes: [note], entitlement: entitlement, context: context)

        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(note.aiMetadata?.suggestedTitle, "価格案とProプラン")
        queue.applyAcceptedSuggestion(to: note, context: context)
        XCTAssertEqual(note.title, "価格案とProプラン")
        XCTAssertEqual(note.tags, ["SaaS", "価格戦略"])
        XCTAssertEqual(entitlement.monthlyAIUsage, 1)

        queue.dismissSuggestion(for: note, context: context)
        XCTAssertEqual(note.aiMetadata?.suggestionStatus, "dismissed")
    }

    func testAIJobQueueRecordsSkippedQuotaAndUnavailableStates() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let ineligible = Note(title: "秘密メモ", markdown: "AI対象外", isAIEligible: false)
        let unavailable = Note(title: "通常メモ", markdown: "AI利用不可")
        let quotaBlocked = Note(title: "制限メモ", markdown: "上限")
        let proEntitlement = SubscriptionEntitlement(plan: .pro, monthlyAIUsage: 0)
        let exhaustedEntitlement = SubscriptionEntitlement(plan: .free, monthlyAIUsage: 200)
        [ineligible, unavailable, quotaBlocked].forEach(context.insert)
        context.insert(proEntitlement)
        context.insert(exhaustedEntitlement)

        let queue = AIJobQueue(organizer: StubOrganizer())
        queue.enqueueOrganization(note: ineligible, allNotes: [ineligible], entitlement: proEntitlement, context: context)

        let unavailableQueue = AIJobQueue(organizer: UnavailableOrganizer())
        unavailableQueue.enqueueOrganization(note: unavailable, allNotes: [unavailable], entitlement: proEntitlement, context: context)
        queue.enqueueOrganization(note: quotaBlocked, allNotes: [quotaBlocked], entitlement: exhaustedEntitlement, context: context)

        let jobs = try context.fetch(FetchDescriptor<AIJob>())
        XCTAssertEqual(jobs.map(\.status), [.skipped])
        XCTAssertEqual(ineligible.aiMetadata?.lastErrorMessage, String(localized: "This note is excluded from AI processing."))
        XCTAssertEqual(unavailable.aiMetadata?.lastErrorMessage, "テスト用にAIを利用できません。")
        XCTAssertEqual(quotaBlocked.aiMetadata?.lastErrorMessage, String(localized: "The Free plan monthly AI organization limit has been reached."))
    }

    func testAIJobQueueFailureDoesNotConsumeUsageAndClearsRunningState() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let note = Note(title: "失敗メモ", markdown: "AI失敗")
        let entitlement = SubscriptionEntitlement(plan: .pro, monthlyAIUsage: 0)
        context.insert(note)
        context.insert(entitlement)

        let queue = AIJobQueue(organizer: FailingOrganizer())
        queue.enqueueOrganization(note: note, allNotes: [note], entitlement: entitlement, context: context)

        try? await Task.sleep(for: .milliseconds(200))

        let job = try XCTUnwrap(context.fetch(FetchDescriptor<AIJob>()).first)
        XCTAssertEqual(job.status, .failed)
        XCTAssertEqual(entitlement.monthlyAIUsage, 0)
        XCTAssertFalse(queue.runningNoteIDs.contains(note.id))
    }

    func testAppIntentRouterMapsDestinationsToWorkspaceModes() {
        XCTAssertEqual(MindVaultAppIntentRouter.workspaceMode(for: MindVaultIntentDestination.graph.rawValue), .graph)
        XCTAssertEqual(MindVaultAppIntentRouter.workspaceMode(for: MindVaultIntentDestination.notes.rawValue), .editor)
        XCTAssertEqual(MindVaultAppIntentRouter.workspaceMode(for: MindVaultIntentDestination.search.rawValue), .search)
        XCTAssertEqual(MindVaultAppIntentRouter.workspaceMode(for: MindVaultIntentDestination.settings.rawValue), .settings)
        XCTAssertNil(MindVaultAppIntentRouter.workspaceMode(for: "unknown"))
    }

    func testAIOrganizationExcludesAIIneligibleNotesFromCandidatesAndRelatedIDs() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let target = Note(title: "雑メモ", markdown: "価格と旅行の断片", collectionName: "未整理")
        let eligible = Note(title: "公開の価格案", markdown: "Pro価格の議論", collectionName: "プロダクト")
        let ineligible = Note(title: "秘密の日記", markdown: "AI対象外の個人メモ", collectionName: "日記", isAIEligible: false)
        let entitlement = SubscriptionEntitlement(plan: .pro, monthlyAIUsage: 0)
        [target, eligible, ineligible].forEach(context.insert)
        context.insert(entitlement)

        let organizer = CapturingOrganizer(
            suggestion: NoteOrganizationSuggestion(
                suggestedTitle: "整理された雑メモ",
                summary: "断片を整理したメモです。",
                suggestedTags: ["価格戦略"],
                relatedNoteTitles: [eligible.title, ineligible.title],
                suggestedCollection: "プロダクト",
                unresolvedLinks: []
            )
        )
        let queue = AIJobQueue(organizer: organizer)
        queue.enqueueOrganization(note: target, allNotes: [target, eligible, ineligible], entitlement: entitlement, context: context)

        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(organizer.capturedRequests.first?.candidateNotes, [eligible.title])
        XCTAssertEqual(target.aiMetadata?.relatedNoteIDs, [eligible.id])
    }

    func testAddedNoteEstablishesOnlyIntendedGraphConnections() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let newNote = Note(
            title: "追加した価格メモ",
            markdown: """
            [[収益モデルのメモ]]

            Pro価格とTeam価格の見直し。#SaaS
            """,
            collectionName: "未整理"
        )
        let explicitTarget = Note(
            title: "収益モデルのメモ",
            markdown: "サブスクリプション収益と月額プラン。",
            collectionName: "プロダクト",
            tags: ["SaaS"]
        )
        let aiRelatedTarget = Note(
            title: "価格案とProプラン",
            markdown: "Pro価格とTeam価格の議論。",
            collectionName: "プロダクト",
            tags: ["価格戦略"]
        )
        let similarButUnconnected = Note(
            title: "料金に関する個人メモ",
            markdown: "価格やプランについて考えた断片。",
            collectionName: "日記",
            tags: ["日記"]
        )
        let entitlement = SubscriptionEntitlement(plan: .pro, monthlyAIUsage: 0)
        let allNotes = [newNote, explicitTarget, aiRelatedTarget, similarButUnconnected]
        allNotes.forEach(context.insert)
        context.insert(entitlement)

        MarkdownIndexingService.reindex(note: newNote, allNotes: allNotes, context: context)
        allNotes.forEach { EmbeddingSearchService.upsertEmbedding(for: $0) }

        let organizer = CapturingOrganizer(
            suggestion: NoteOrganizationSuggestion(
                suggestedTitle: "追加した価格メモ",
                summary: "価格と収益モデルを整理するメモです。",
                suggestedTags: ["価格戦略"],
                relatedNoteTitles: [aiRelatedTarget.title],
                suggestedCollection: "プロダクト",
                unresolvedLinks: []
            )
        )
        let queue = AIJobQueue(organizer: organizer)
        queue.enqueueOrganization(note: newNote, allNotes: allNotes, entitlement: entitlement, context: context)

        try? await Task.sleep(for: .milliseconds(200))

        let noteLinks = try context.fetch(FetchDescriptor<NoteLink>())
        let aiEdges = try context.fetch(FetchDescriptor<GraphEdge>())
        let graph = GraphBuilder.build(notes: allNotes, links: noteLinks, aiEdges: aiEdges)

        XCTAssertTrue(graph.hasLink(from: newNote, to: explicitTarget, kind: .wiki))
        XCTAssertTrue(graph.hasLink(from: newNote, to: explicitTarget, kind: .tagCooccurrence))
        XCTAssertTrue(graph.hasLink(from: newNote, to: aiRelatedTarget, kind: .aiRelated))
        XCTAssertFalse(graph.hasAnyLink(between: newNote, and: similarButUnconnected))
        XCTAssertTrue(
            EmbeddingSearchService.rank(query: "価格 プラン", notes: allNotes).contains { $0.note.id == similarButUnconnected.id },
            "Embedding search may surface similar notes, but similarity alone should not create a graph edge."
        )
    }

    func testSeedDataIncludesOnboardingGuideConnections() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        SeedData.ensureSeedData(context: context, languageCode: "en")

        let notes = try context.fetch(FetchDescriptor<Note>())
        let noteLinks = try context.fetch(FetchDescriptor<NoteLink>())
        let aiEdges = try context.fetch(FetchDescriptor<GraphEdge>())
        let graph = GraphBuilder.build(notes: notes, links: noteLinks, aiEdges: aiEdges)

        let welcome = try XCTUnwrap(notes.first { $0.title == "Welcome to MindVault" })
        let writing = try XCTUnwrap(notes.first { $0.title == "Writing Notes" })
        let graphGuide = try XCTUnwrap(notes.first { $0.title == "Explore with the Graph" })
        let aiGuide = try XCTUnwrap(notes.first { $0.title == "Use AI Organization" })
        let dailyNote = try XCTUnwrap(notes.first { $0.isDailyNote })

        XCTAssertNil(notes.first { $0.title == "追加した価格メモ" })
        XCTAssertNil(notes.first { $0.title == "価格案とProプラン" })
        XCTAssertNotNil(dailyNote.dailyDate)
        XCTAssertEqual(welcome.collectionName, "Start Here")
        XCTAssertEqual(welcome.aiMetadata?.relatedNoteIDs, [aiGuide.id])
        XCTAssertTrue(graph.hasLink(from: welcome, to: writing, kind: .wiki))
        XCTAssertTrue(graph.hasLink(from: welcome, to: graphGuide, kind: .wiki))
        XCTAssertFalse(graph.hasAnyLink(between: welcome, and: writing, kind: .tagCooccurrence))
        XCTAssertTrue(graph.hasLink(from: welcome, to: aiGuide, kind: .aiRelated))
    }

    func testSeedDataUsesJapaneseOnboardingWhenRequested() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        SeedData.ensureSeedData(context: context, languageCode: "ja")

        let notes = try context.fetch(FetchDescriptor<Note>())
        let noteLinks = try context.fetch(FetchDescriptor<NoteLink>())
        let aiEdges = try context.fetch(FetchDescriptor<GraphEdge>())
        let graph = GraphBuilder.build(notes: notes, links: noteLinks, aiEdges: aiEdges)

        let welcome = try XCTUnwrap(notes.first { $0.title == "MindVaultへようこそ" })
        let writing = try XCTUnwrap(notes.first { $0.title == "メモを書く基本" })
        let graphGuide = try XCTUnwrap(notes.first { $0.title == "グラフで探す" })
        let aiGuide = try XCTUnwrap(notes.first { $0.title == "AI整理を使う" })

        XCTAssertEqual(welcome.collectionName, "はじめに")
        XCTAssertEqual(welcome.aiMetadata?.suggestedTags, ["はじめに", "使い方"])
        XCTAssertTrue(graph.hasLink(from: welcome, to: writing, kind: .wiki))
        XCTAssertTrue(graph.hasLink(from: welcome, to: graphGuide, kind: .wiki))
        XCTAssertTrue(graph.hasLink(from: welcome, to: aiGuide, kind: .aiRelated))
    }

    func testSeedDataReplacesLegacyDemoNotesWithOnboardingGuides() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let legacyPricing = Note(title: "価格案とProプラン", markdown: "#価格戦略", tags: ["価格戦略"])
        let legacyDemo = Note(title: "追加した価格メモ", markdown: "[[価格案とProプラン]]", tags: ["価格戦略"])
        context.insert(legacyPricing)
        context.insert(legacyDemo)
        context.insert(SubscriptionEntitlement(plan: .free, monthlyAIUsage: 42))
        MarkdownIndexingService.reindex(note: legacyDemo, allNotes: [legacyPricing, legacyDemo], context: context)
        context.insert(GraphEdge(sourceNoteID: legacyDemo.id, targetNoteID: legacyPricing.id, kind: .aiRelated))
        context.insert(AIJob(noteID: legacyDemo.id, status: .queued))
        try context.save()

        SeedData.ensureSeedData(context: context, languageCode: "en")

        let notes = try context.fetch(FetchDescriptor<Note>())
        let noteLinks = try context.fetch(FetchDescriptor<NoteLink>())
        let graphEdges = try context.fetch(FetchDescriptor<GraphEdge>())
        let aiJobs = try context.fetch(FetchDescriptor<AIJob>())
        let entitlement = try XCTUnwrap(context.fetch(FetchDescriptor<SubscriptionEntitlement>()).first)

        XCTAssertNil(notes.first { $0.title == "価格案とProプラン" })
        XCTAssertNil(notes.first { $0.title == "追加した価格メモ" })
        XCTAssertNotNil(notes.first { $0.title == "Welcome to MindVault" })
        XCTAssertNotNil(notes.first { $0.title == "Writing Notes" })
        XCTAssertEqual(entitlement.monthlyAIUsage, 0)
        XCTAssertTrue(noteLinks.allSatisfy { link in
            guard notes.contains(where: { $0.id == link.sourceNoteID }) else { return false }
            guard let targetID = link.targetNoteID else { return true }
            return notes.contains { $0.id == targetID }
        })
        XCTAssertTrue(graphEdges.allSatisfy { edge in
            notes.contains { $0.id == edge.sourceNoteID } && notes.contains { $0.id == edge.targetNoteID }
        })
        XCTAssertTrue(aiJobs.allSatisfy { job in
            notes.contains { $0.id == job.noteID }
        })
    }

    func testSeedDataDoesNotRewriteUserNotesAfterLegacyCleanup() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let legacyDemo = Note(title: "追加した価格メモ", markdown: "[[価格案とProプラン]]", tags: ["価格戦略"])
        let userNote = Note(title: "User Travel Note", markdown: "#Travel\nKeep this note.", collectionName: "Personal", tags: ["Travel"])
        context.insert(legacyDemo)
        context.insert(userNote)
        try context.save()

        SeedData.ensureSeedData(context: context)

        let notes = try context.fetch(FetchDescriptor<Note>())
        XCTAssertNil(notes.first { $0.title == "追加した価格メモ" })
        XCTAssertNotNil(notes.first { $0.title == "User Travel Note" })
        XCTAssertNil(notes.first { $0.title == "Welcome to MindVault" })
    }

    func testStringCatalogUsesEnglishSourceAndJapaneseTranslations() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("MindVault/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])

        XCTAssertEqual(root["sourceLanguage"] as? String, "en")
        XCTAssertFalse(strings.keys.contains { key in
            key.range(of: #"[ぁ-んァ-ヶ一-龠]"#, options: .regularExpression) != nil
        })

        for key in ["Graph", "Notes", "AI Suggestions", "Welcome to MindVault", "Settings & Plan", "Import / Export"] {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], "Missing catalog key: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], "Missing localizations for \(key)")
            let japanese = try XCTUnwrap(localizations["ja"] as? [String: Any], "Missing ja localization for \(key)")
            let stringUnit = try XCTUnwrap(japanese["stringUnit"] as? [String: Any], "Missing ja string unit for \(key)")
            XCTAssertFalse((stringUnit["value"] as? String ?? "").isEmpty)
        }

        for (key, value) in strings {
            guard
                let entry = value as? [String: Any],
                let localizations = entry["localizations"] as? [String: Any],
                let english = localizations["en"] as? [String: Any],
                let stringUnit = english["stringUnit"] as? [String: Any],
                let englishValue = stringUnit["value"] as? String
            else {
                continue
            }
            XCTAssertNil(
                englishValue.range(of: #"[ぁ-んァ-ヶ一-龠]"#, options: .regularExpression),
                "English localization for \(key) contains Japanese text."
            )
        }
    }

    func testSubscriptionLimits() {
        let entitlement = SubscriptionEntitlement(plan: .free, monthlyAIUsage: 200)

        XCTAssertEqual(entitlement.remainingAIOrganizeCount, 0)
        entitlement.aiCreditBalance = 10
        XCTAssertEqual(entitlement.remainingAIOrganizeCount, 10)
    }

    func testDateFilters() {
        let now = Date.now
        let older = Calendar.current.date(byAdding: .day, value: -12, to: now) ?? now

        XCTAssertTrue(NoteDateFilter.today.contains(now))
        XCTAssertTrue(NoteDateFilter.last7Days.contains(now))
        XCTAssertFalse(NoteDateFilter.last7Days.contains(older))
        XCTAssertTrue(NoteDateFilter.last30Days.contains(older))
    }

    func testDailyNoteNormalizesDailyDate() {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 4, hour: 15, minute: 30)) ?? .now
        let note = Note(title: "デイリーノート 2026/06/04", markdown: "", isDailyNote: true, dailyDate: date)

        XCTAssertEqual(note.dailyDate, calendar.startOfDay(for: date))
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Note.self,
            NoteContent.self,
            Tag.self,
            NoteCollection.self,
            NoteLink.self,
            GraphEdge.self,
            NoteAIMetadata.self,
            AIJob.self,
            NoteEmbedding.self,
            SubscriptionEntitlement.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

private extension KnowledgeGraph {
    func hasLink(from source: Note, to target: Note, kind: LinkKind) -> Bool {
        links.contains { link in
            link.sourceID == source.id && link.targetID == target.id && link.kind == kind
        }
    }

    func hasAnyLink(between first: Note, and second: Note) -> Bool {
        links.contains { link in
            (link.sourceID == first.id && link.targetID == second.id)
                || (link.sourceID == second.id && link.targetID == first.id)
        }
    }

    func hasAnyLink(between first: Note, and second: Note, kind: LinkKind) -> Bool {
        links.contains { link in
            link.kind == kind
                && (
                    (link.sourceID == first.id && link.targetID == second.id)
                        || (link.sourceID == second.id && link.targetID == first.id)
                )
        }
    }
}

@MainActor
private final class StubOrganizer: NoteOrganizing {
    func availability() -> AIAvailabilityState {
        .available
    }

    func organize(_ request: NoteOrganizationRequest) async throws -> NoteOrganizationSuggestion {
        NoteOrganizationSuggestion(
            suggestedTitle: "価格案とProプラン",
            summary: "Pro価格の議論を整理したメモです。",
            suggestedTags: ["価格戦略", "SaaS"],
            relatedNoteTitles: [],
            suggestedCollection: "プロダクト",
            unresolvedLinks: ["収益モデルのメモ"]
        )
    }

    func answer(question: String, notes: [Note]) async throws -> ChatAnswer {
        ChatAnswer(question: question, answer: "価格案はPro $14.99、Team $29.99です。", sourceNoteIDs: notes.map(\.id))
    }
}

@MainActor
private final class CapturingOrganizer: NoteOrganizing {
    var capturedRequests: [NoteOrganizationRequest] = []
    let suggestion: NoteOrganizationSuggestion

    init(suggestion: NoteOrganizationSuggestion) {
        self.suggestion = suggestion
    }

    func availability() -> AIAvailabilityState {
        .available
    }

    func organize(_ request: NoteOrganizationRequest) async throws -> NoteOrganizationSuggestion {
        capturedRequests.append(request)
        return suggestion
    }

    func answer(question: String, notes: [Note]) async throws -> ChatAnswer {
        ChatAnswer(question: question, answer: "", sourceNoteIDs: [])
    }
}

@MainActor
private final class UnavailableOrganizer: NoteOrganizing {
    func availability() -> AIAvailabilityState {
        .unavailable("テスト用にAIを利用できません。")
    }

    func organize(_ request: NoteOrganizationRequest) async throws -> NoteOrganizationSuggestion {
        throw NSError(domain: "UnavailableOrganizer", code: 1)
    }

    func answer(question: String, notes: [Note]) async throws -> ChatAnswer {
        ChatAnswer(question: question, answer: "", sourceNoteIDs: [])
    }
}

@MainActor
private final class FailingOrganizer: NoteOrganizing {
    func availability() -> AIAvailabilityState {
        .available
    }

    func organize(_ request: NoteOrganizationRequest) async throws -> NoteOrganizationSuggestion {
        throw NSError(domain: "FailingOrganizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI整理に失敗しました。"])
    }

    func answer(question: String, notes: [Note]) async throws -> ChatAnswer {
        ChatAnswer(question: question, answer: "", sourceNoteIDs: [])
    }
}
