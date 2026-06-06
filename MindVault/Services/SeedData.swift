import Foundation
import SwiftData

enum SeedData {
    static func ensureSeedData(context: ModelContext, languageCode: String? = nil) {
        let content = localizedContent(languageCode: languageCode)
        let didRemoveLegacyDemoNotes = removeLegacyDemoNotes(context: context)
        if didRemoveLegacyDemoNotes {
            resetLegacyEntitlementUsage(context: context)
        }

        let existingNoteCount = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
        if existingNoteCount == 0 || shouldInsertOnboardingGuides(didRemoveLegacyDemoNotes: didRemoveLegacyDemoNotes, context: context) {
            let notes = content.onboardingNotes()
            notes.forEach(context.insert)

            ensureCollections(content.collectionNames, context: context)
            ensureEntitlement(context: context)

            notes.forEach { note in
                MarkdownIndexingService.reindex(note: note, allNotes: notes, context: context)
            }

            connectOnboardingNotes(notes: notes, content: content, context: context)
        }
        resetStarterEntitlementUsageIfNeeded(context: context)
        try? context.save()
    }

    static func onboardingNotes(languageCode: String? = nil) -> [Note] {
        localizedContent(languageCode: languageCode).onboardingNotes()
    }

    private static func englishOnboardingNotes() -> [Note] {
        let now = Date.now
        let welcome = Note(
            title: "Welcome to MindVault",
            markdown: """
            ## Start Here
            MindVault is a knowledge notebook where relationships grow as you write.

            - See how notes connect in the graph as soon as the app opens.
            - Write `[[Note Name]]` inside a note to link to another note.
            - Add `#tags` to help related notes gather near each other in the graph.

            Next, open [[Writing Notes]] and [[Explore with the Graph]] to learn the flow.
            #GettingStarted #Guide
            """,
            collectionName: "Start Here",
            createdAt: now.addingTimeInterval(-3_600 * 8),
            updatedAt: now.addingTimeInterval(-900),
            tags: ["GettingStarted", "Guide"],
            isPinned: true
        )

        let writing = Note(
            title: "Writing Notes",
            markdown: """
            ## Writing Basics
            Mix prose, bullets, and headings freely. Edits are saved automatically.

            ## Writing Connections
            - Use links like `[[Explore with the Graph]]` to connect notes.
            - Use tags like `#Reading` or `#Work` to make notes easier to find later.
            - It is fine to start small even when an idea is not organized yet.

            When you want AI help, open [[Use AI Organization]].
            #Guide #Markdown
            """,
            collectionName: "Guide",
            createdAt: now.addingTimeInterval(-86_400),
            updatedAt: now.addingTimeInterval(-700),
            tags: ["Guide", "Markdown"]
        )

        let graph = Note(
            title: "Explore with the Graph",
            markdown: """
            ## What the Graph Shows
            The graph brings together links, tags, and AI-suggested related notes.

            - Tap a node to select that note.
            - Use Open to jump into the note body.
            - Zoom, pan, and reset the layout to make the map readable.

            Start by looking at the links between [[Welcome to MindVault]], [[Writing Notes]], and [[Use AI Organization]].
            #Guide #Graph
            """,
            collectionName: "Guide",
            createdAt: now.addingTimeInterval(-72_000),
            updatedAt: now.addingTimeInterval(-600),
            tags: ["Guide", "Graph"]
        )

        let ai = Note(
            title: "Use AI Organization",
            markdown: """
            ## How AI Organization Works
            AI organization does not rewrite your notes on its own. You review each suggestion and approve only what helps.

            - Review title, summary, tag, and collection suggestions.
            - See candidate notes that may be related.
            - Dismiss suggestions you do not need.

            Try a short note first, then add links or tags like [[Writing Notes]] before running AI suggestions.
            #AI #Guide
            """,
            collectionName: "AI",
            createdAt: now.addingTimeInterval(-50_000),
            updatedAt: now.addingTimeInterval(-500),
            tags: ["AI", "Guide"]
        )

        let daily = Note(
            title: "Daily Note Example \(Self.dailyTitleDateFormatter.string(from: now))",
            markdown: """
            ## Today's Notes
            - Write what you thought about this morning
            - Link meeting or learning notes later
            - Return to [[Writing Notes]] when something needs structure

            ## Reflection
            At the end of the day, grow only the insights worth keeping into separate notes so knowledge connects naturally.
            #Journal #Unorganized
            """,
            collectionName: "Journal",
            createdAt: now.addingTimeInterval(-400),
            updatedAt: now.addingTimeInterval(-400),
            tags: ["Journal", "Unorganized"],
            isDailyNote: true,
            dailyDate: now
        )

        let reading = Note(
            title: "Growing Reading Notes",
            markdown: """
            ## A Reading Note Shape
            Keep ideas from books in your own words instead of stopping at quotes.

            - Put interesting concepts in [[Idea Fragments]] first.
            - Revisit practical ideas in [[Weekly Review]].
            - Connect related themes with #Reading and #Learning.

            Use the link style from [[Writing Notes]] to follow context later in the graph.
            #Reading #Learning #Guide
            """,
            collectionName: "Guide",
            createdAt: now.addingTimeInterval(-43_200),
            updatedAt: now.addingTimeInterval(-470),
            tags: ["Reading", "Learning", "Guide"]
        )

        let meeting = Note(
            title: "Turn Meeting Notes into Action",
            markdown: """
            ## What to Keep After a Meeting
            Meeting notes become reusable when decisions, open questions, and next actions are separated.

            - Link decisions to [[Project Design Notes]].
            - Review follow-ups in [[Weekly Review]].
            - Summarize important stakeholder comments briefly.

            #Work #Review #Unorganized
            """,
            collectionName: "Guide",
            createdAt: now.addingTimeInterval(-39_000),
            updatedAt: now.addingTimeInterval(-440),
            tags: ["Work", "Review", "Unorganized"]
        )

        let project = Note(
            title: "Project Design Notes",
            markdown: """
            ## What to Check During Design
            Keep the project's purpose, users, success metrics, and constraints in one note.

            Use [[Use AI Organization]] for candidate tags, then check [[Tag Design]] for the right level of detail.

            #Work #Design #AI
            """,
            collectionName: "AI",
            createdAt: now.addingTimeInterval(-36_000),
            updatedAt: now.addingTimeInterval(-420),
            tags: ["Work", "Design", "AI"]
        )

        let search = Note(
            title: "Search Query Examples",
            markdown: """
            ## How to Search
            Search with questions as well as keywords like price, meeting, or reading to widen useful candidates.

            - What decisions did we make last week?
            - Which #AI notes are still unorganized?
            - Which notes are close to [[Explore with the Graph]]?

            #Search #AI #Guide
            """,
            collectionName: "AI",
            createdAt: now.addingTimeInterval(-32_000),
            updatedAt: now.addingTimeInterval(-360),
            tags: ["Search", "AI", "Guide"]
        )

        let importNote = Note(
            title: "Import Workflow",
            markdown: """
            ## Moving Notes In
            Import Markdown files and MindVault will reflect existing links and tags in the graph.

            Use [[Tag Design]] to clean up tags, then use [[Explore with the Graph]] to find isolated notes.

            #Import #Markdown #Graph
            """,
            collectionName: "Import",
            createdAt: now.addingTimeInterval(-28_000),
            updatedAt: now.addingTimeInterval(-330),
            tags: ["Import", "Markdown", "Graph"]
        )

        let tags = Note(
            title: "Tag Design",
            markdown: """
            ## Avoid Too Many Tags
            Keep only tags that work as search axes.

            - #Guide is for operating guides.
            - #AI is for useful AI suggestion moments.
            - #Review is for notes you plan to revisit.

            Reusing the same tags in [[Search Query Examples]] and [[Weekly Review]] helps graph clusters form naturally.
            #Design #Search #Review
            """,
            collectionName: "Guide",
            createdAt: now.addingTimeInterval(-24_000),
            updatedAt: now.addingTimeInterval(-300),
            tags: ["Design", "Search", "Review"]
        )

        let weekly = Note(
            title: "Weekly Review",
            markdown: """
            ## Once a Week
            Review notes added this week and connect isolated ones to the notes they belong with.

            Look at [[Turn Meeting Notes into Action]], [[Growing Reading Notes]], and [[Idea Fragments]] to choose what to grow next.

            #Review #Journal #Work
            """,
            collectionName: "Journal",
            createdAt: now.addingTimeInterval(-18_000),
            updatedAt: now.addingTimeInterval(-260),
            tags: ["Review", "Journal", "Work"]
        )

        let idea = Note(
            title: "Idea Fragments",
            markdown: """
            ## Thoughts Without Names Yet
            Put rough ideas down first, then use [[Use AI Organization]] and [[Tag Design]] to give them shape later.

            - Hypotheses from reading
            - Improvement ideas from meetings
            - Questions you want search to rediscover

            #Unorganized #Learning #AI
            """,
            collectionName: "Unorganized",
            createdAt: now.addingTimeInterval(-12_000),
            updatedAt: now.addingTimeInterval(-220),
            tags: ["Unorganized", "Learning", "AI"]
        )

        return [welcome, writing, graph, ai, daily, reading, meeting, project, search, importNote, tags, weekly, idea]
    }

    private static func japaneseOnboardingNotes() -> [Note] {
        let now = Date.now
        let welcome = Note(
            title: "MindVaultへようこそ",
            markdown: """
            ## まず知っておくこと
            MindVaultは、メモを書きながら関係性を育てていく知識ノートです。

            - 起動直後のグラフで、メモ同士のつながりを見られます。
            - メモ内で `[[メモ名]]` と書くと、別のメモへのリンクになります。
            - `#タグ` を付けると、同じタグを持つメモがグラフで近くなります。

            次は [[メモを書く基本]] と [[グラフで探す]] を開いて、操作の流れを確認してください。
            #はじめに #使い方
            """,
            collectionName: "はじめに",
            createdAt: now.addingTimeInterval(-3_600 * 8),
            updatedAt: now.addingTimeInterval(-900),
            tags: ["はじめに", "使い方"],
            isPinned: true
        )

        let writing = Note(
            title: "メモを書く基本",
            markdown: """
            ## 書き方のコツ
            文章、箇条書き、見出しを自由に混ぜて書けます。編集内容は自動保存されます。

            ## つながる書き方
            - `[[グラフで探す]]` のように書くと、メモ同士がリンクされます。
            - `#読書` や `#仕事` のようなタグで、あとから探しやすくできます。
            - アイデアがまとまっていなくても、まず短く書いて大丈夫です。

            AIに整理を任せたいときは [[AI整理を使う]] を確認してください。
            #使い方 #Markdown
            """,
            collectionName: "使い方",
            createdAt: now.addingTimeInterval(-86_400),
            updatedAt: now.addingTimeInterval(-700),
            tags: ["使い方", "Markdown"]
        )

        let graph = Note(
            title: "グラフで探す",
            markdown: """
            ## グラフでできること
            グラフでは、リンク、タグ、AIが提案した関連メモをまとめて確認できます。

            - ノードをタップすると、そのメモを選択できます。
            - 「開く」からメモ本文へ移動できます。
            - 拡大、縮小、自動配置で見やすい位置に戻せます。

            まずは [[MindVaultへようこそ]]、[[メモを書く基本]]、[[AI整理を使う]] のつながりを見てください。
            #使い方 #グラフ
            """,
            collectionName: "使い方",
            createdAt: now.addingTimeInterval(-72_000),
            updatedAt: now.addingTimeInterval(-600),
            tags: ["使い方", "グラフ"]
        )

        let ai = Note(
            title: "AI整理を使う",
            markdown: """
            ## AI整理の考え方
            AI整理は、勝手に書き換える機能ではありません。提案を見て、必要なものだけ承認できます。

            - タイトル案、要約、タグ、コレクションを確認できます。
            - 関連しそうなメモを候補として表示します。
            - 不要な提案は却下できます。

            まずは短いメモを作り、[[メモを書く基本]] のようなリンクやタグを入れてからAI提案を試してください。
            #AI活用 #使い方
            """,
            collectionName: "AI活用",
            createdAt: now.addingTimeInterval(-50_000),
            updatedAt: now.addingTimeInterval(-500),
            tags: ["AI活用", "使い方"]
        )

        let daily = Note(
            title: "デイリーノートの例 \(Self.dailyTitleDateFormatter.string(from: now))",
            markdown: """
            ## 今日のメモ
            - 朝に考えたことを書く
            - 会議や学習のメモをあとでリンクする
            - 気になったことを [[メモを書く基本]] に戻って整理する

            ## ふりかえり
            1日の終わりに、残したい気づきだけを別メモに育てると知識がつながりやすくなります。
            #日記 #未整理
            """,
            collectionName: "日記",
            createdAt: now.addingTimeInterval(-400),
            updatedAt: now.addingTimeInterval(-400),
            tags: ["日記", "未整理"],
            isDailyNote: true,
            dailyDate: now
        )

        let reading = Note(
            title: "読書メモの育て方",
            markdown: """
            ## 読書メモの型
            本から得たアイデアは、引用だけで終わらせずに自分の言葉で残します。

            - 気になった概念は [[アイデアの断片]] に一度置く
            - 実践できる内容は [[週次レビュー]] で見返す
            - 関連するテーマは #読書 と #学習 でつなぐ

            [[メモを書く基本]] のリンク記法を使うと、あとからグラフ上で文脈を追いやすくなります。
            #読書 #学習 #使い方
            """,
            collectionName: "使い方",
            createdAt: now.addingTimeInterval(-43_200),
            updatedAt: now.addingTimeInterval(-470),
            tags: ["読書", "学習", "使い方"]
        )

        let meeting = Note(
            title: "会議メモから行動へ",
            markdown: """
            ## 会議後に残すもの
            会議メモは決定事項、未決事項、次の一手に分けると再利用しやすくなります。

            - 決定事項は [[プロジェクト設計メモ]] にリンクする
            - 宿題は [[週次レビュー]] で確認する
            - 関係者の発言は短く要約する

            #仕事 #レビュー #未整理
            """,
            collectionName: "使い方",
            createdAt: now.addingTimeInterval(-39_000),
            updatedAt: now.addingTimeInterval(-440),
            tags: ["仕事", "レビュー", "未整理"]
        )

        let project = Note(
            title: "プロジェクト設計メモ",
            markdown: """
            ## 設計時に見る観点
            プロジェクトの目的、ユーザー、成功指標、制約をひとつのメモにまとめます。

            [[AI整理を使う]] で候補タグを出し、[[タグ設計]] で分類の粒度を確認します。

            #仕事 #設計 #AI活用
            """,
            collectionName: "AI活用",
            createdAt: now.addingTimeInterval(-36_000),
            updatedAt: now.addingTimeInterval(-420),
            tags: ["仕事", "設計", "AI活用"]
        )

        let search = Note(
            title: "検索クエリの例",
            markdown: """
            ## 探し方
            「価格」「会議」「読書」のような単語だけでなく、問いの形で検索すると候補が広がります。

            - 先週の決定事項は？
            - #AI活用 のメモで未整理のものは？
            - [[グラフで探す]] と近いメモは？

            #検索 #AI活用 #使い方
            """,
            collectionName: "AI活用",
            createdAt: now.addingTimeInterval(-32_000),
            updatedAt: now.addingTimeInterval(-360),
            tags: ["検索", "AI活用", "使い方"]
        )

        let importNote = Note(
            title: "インポート運用",
            markdown: """
            ## 他のノートから移す
            Markdownファイルを取り込むと、既存のリンクやタグも MindVault のグラフに反映されます。

            [[タグ設計]] でタグを整理し、[[グラフで探す]] で孤立したメモを見つけます。

            #インポート #Markdown #グラフ
            """,
            collectionName: "インポート",
            createdAt: now.addingTimeInterval(-28_000),
            updatedAt: now.addingTimeInterval(-330),
            tags: ["インポート", "Markdown", "グラフ"]
        )

        let tags = Note(
            title: "タグ設計",
            markdown: """
            ## タグを増やしすぎない
            タグは検索軸として使うものだけに絞ります。

            - #使い方 は操作ガイド
            - #AI活用 はAI提案の使いどころ
            - #レビュー は見返す前提のメモ

            [[検索クエリの例]] と [[週次レビュー]] にも同じタグを使うと、グラフのクラスタが自然にできます。
            #設計 #検索 #レビュー
            """,
            collectionName: "使い方",
            createdAt: now.addingTimeInterval(-24_000),
            updatedAt: now.addingTimeInterval(-300),
            tags: ["設計", "検索", "レビュー"]
        )

        let weekly = Note(
            title: "週次レビュー",
            markdown: """
            ## 週に一度見る
            その週に増えたメモを見返し、孤立したものを必要なメモへリンクします。

            [[会議メモから行動へ]]、[[読書メモの育て方]]、[[アイデアの断片]] を見て、次に育てるテーマを選びます。

            #レビュー #日記 #仕事
            """,
            collectionName: "日記",
            createdAt: now.addingTimeInterval(-18_000),
            updatedAt: now.addingTimeInterval(-260),
            tags: ["レビュー", "日記", "仕事"]
        )

        let idea = Note(
            title: "アイデアの断片",
            markdown: """
            ## まだ名前のない考え
            思いついたことは粗いまま置いて、あとで [[AI整理を使う]] と [[タグ設計]] で形にします。

            - 読書から得た仮説
            - 会議中に浮かんだ改善案
            - 検索で再発見したい問い

            #未整理 #学習 #AI活用
            """,
            collectionName: "未整理",
            createdAt: now.addingTimeInterval(-12_000),
            updatedAt: now.addingTimeInterval(-220),
            tags: ["未整理", "学習", "AI活用"]
        )

        return [welcome, writing, graph, ai, daily, reading, meeting, project, search, importNote, tags, weekly, idea]
    }

    private static func localizedContent(languageCode: String?) -> LocalizedSeedContent {
        let resolvedCode = languageCode ?? Bundle.main.preferredLocalizations.first ?? Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en"
        if resolvedCode.lowercased().hasPrefix("ja") {
            return .japanese
        }
        return .english
    }

    private static func connectOnboardingNotes(notes: [Note], content: LocalizedSeedContent, context: ModelContext) {
        guard
            let welcome = notes.first(where: { $0.title == content.welcomeTitle }),
            let graph = notes.first(where: { $0.title == content.graphTitle }),
            let ai = notes.first(where: { $0.title == content.aiTitle })
        else {
            return
        }

        let metadata = welcome.aiMetadata ?? NoteAIMetadata(noteID: welcome.id)
        if welcome.aiMetadata == nil {
            welcome.aiMetadata = metadata
        }
        metadata.suggestedTitle = welcome.title
        metadata.summary = content.aiSummary
        metadata.suggestedTags = content.aiSuggestedTags
        metadata.suggestedCollection = content.aiSuggestedCollection
        metadata.relatedNoteIDs = [ai.id]
        metadata.unresolvedLinkTargets = []
        metadata.lastOrganizedAt = .now
        metadata.suggestionStatus = "draft"
        metadata.lastErrorMessage = nil

        upsertGraphEdge(sourceNoteID: welcome.id, targetNoteID: ai.id, kind: .aiRelated, weight: 0.72, context: context)
        upsertGraphEdge(sourceNoteID: graph.id, targetNoteID: ai.id, kind: .aiRelated, weight: 0.56, context: context)
    }

    private static func removeLegacyDemoNotes(context: ModelContext) -> Bool {
        let notes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        var legacyNotes: [Note] = []
        for note in notes where isLegacyDemoNote(note) {
            legacyNotes.append(note)
        }
        guard !legacyNotes.isEmpty else { return false }

        let legacyIDs = Set(legacyNotes.map(\.id))
        deleteLegacyArtifacts(noteIDs: legacyIDs, context: context)
        legacyNotes.forEach(context.delete)
        return true
    }

    private static func isLegacyDemoNote(_ note: Note) -> Bool {
        legacyDemoTitles.contains(note.title)
            || (
                note.title.hasPrefix("デイリーノート ")
                    && note.markdown.contains("価格案とProプラン")
                    && note.markdown.contains("Graph初期表示")
            )
            || (
                note.title.hasPrefix("Daily Note ")
                    && note.markdown.contains("Pricing and Pro Plan")
                    && note.markdown.contains("Initial graph view")
            )
    }

    private static func shouldInsertOnboardingGuides(didRemoveLegacyDemoNotes: Bool, context: ModelContext) -> Bool {
        guard didRemoveLegacyDemoNotes else { return false }
        let notes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        return notes.isEmpty
    }

    private static func deleteLegacyArtifacts(noteIDs: Set<UUID>, context: ModelContext) {
        let noteLinks = (try? context.fetch(FetchDescriptor<NoteLink>())) ?? []
        noteLinks
            .filter { noteIDs.contains($0.sourceNoteID) || $0.targetNoteID.map(noteIDs.contains) == true }
            .forEach(context.delete)

        let graphEdges = (try? context.fetch(FetchDescriptor<GraphEdge>())) ?? []
        graphEdges
            .filter { noteIDs.contains($0.sourceNoteID) || noteIDs.contains($0.targetNoteID) }
            .forEach(context.delete)

        let aiJobs = (try? context.fetch(FetchDescriptor<AIJob>())) ?? []
        aiJobs
            .filter { noteIDs.contains($0.noteID) }
            .forEach(context.delete)
    }

    private static func ensureCollections(_ names: [String], context: ModelContext) {
        let existingNames = Set(((try? context.fetch(FetchDescriptor<NoteCollection>())) ?? []).map(\.name))
        names
            .filter { !existingNames.contains($0) }
            .forEach { context.insert(NoteCollection(name: $0)) }
    }

    private static func ensureEntitlement(context: ModelContext) {
        let existingEntitlements = (try? context.fetch(FetchDescriptor<SubscriptionEntitlement>())) ?? []
        if existingEntitlements.isEmpty {
            context.insert(SubscriptionEntitlement(plan: .free, monthlyAIUsage: 0, aiCreditBalance: 0, storageLimitGB: 5))
        }
    }

    private static func resetLegacyEntitlementUsage(context: ModelContext) {
        let existingEntitlements = (try? context.fetch(FetchDescriptor<SubscriptionEntitlement>())) ?? []
        for entitlement in existingEntitlements where entitlement.plan == .free && entitlement.monthlyAIUsage == 42 {
            entitlement.monthlyAIUsage = 0
            entitlement.updatedAt = .now
        }
    }

    private static func resetStarterEntitlementUsageIfNeeded(context: ModelContext) {
        guard isStarterOnboardingVault(context: context) else { return }
        resetLegacyEntitlementUsage(context: context)
    }

    private static func isStarterOnboardingVault(context: ModelContext) -> Bool {
        let notes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        guard !notes.isEmpty else { return false }
        return notes.allSatisfy { note in
            onboardingGuideTitles.contains(note.title)
                || note.title.hasPrefix("Daily Note Example ")
                || note.title.hasPrefix("デイリーノートの例 ")
        }
    }

    private static func upsertGraphEdge(sourceNoteID: UUID, targetNoteID: UUID, kind: LinkKind, weight: Double, context: ModelContext) {
        let kindRaw = kind.rawValue
        let descriptor = FetchDescriptor<GraphEdge>(predicate: #Predicate { edge in
            edge.sourceNoteID == sourceNoteID && edge.targetNoteID == targetNoteID && edge.kindRaw == kindRaw
        })
        if let existing = try? context.fetch(descriptor), let edge = existing.first {
            edge.weight = weight
            edge.updatedAt = .now
            return
        }

        context.insert(GraphEdge(sourceNoteID: sourceNoteID, targetNoteID: targetNoteID, kind: kind, weight: weight))
    }

    private static let dailyTitleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    private static let legacyDemoTitles: Set<String> = [
        "Pricing and Pro Plan",
        "Team Kickoff Note",
        "User Interview Summary",
        "Revenue Model Note",
        "Added Pricing Note",
        "Personal Pricing Note",
        "価格案とProプラン",
        "チームキックオフメモ",
        "ユーザーインタビュー要約",
        "収益モデルのメモ",
        "追加した価格メモ",
        "料金に関する個人メモ"
    ]

    private static let onboardingGuideTitles: Set<String> = [
        "Welcome to MindVault",
        "Writing Notes",
        "Explore with the Graph",
        "Use AI Organization",
        "Growing Reading Notes",
        "Turn Meeting Notes into Action",
        "Project Design Notes",
        "Search Query Examples",
        "Import Workflow",
        "Tag Design",
        "Weekly Review",
        "Idea Fragments",
        "MindVaultへようこそ",
        "メモを書く基本",
        "グラフで探す",
        "AI整理を使う",
        "読書メモの育て方",
        "会議メモから行動へ",
        "プロジェクト設計メモ",
        "検索クエリの例",
        "インポート運用",
        "タグ設計",
        "週次レビュー",
        "アイデアの断片"
    ]

    private enum SeedLanguage {
        case english
        case japanese
    }

    private struct LocalizedSeedContent {
        let language: SeedLanguage
        let collectionNames: [String]
        let welcomeTitle: String
        let graphTitle: String
        let aiTitle: String
        let aiSummary: String
        let aiSuggestedTags: [String]
        let aiSuggestedCollection: String

        func onboardingNotes() -> [Note] {
            switch language {
            case .english:
                SeedData.englishOnboardingNotes()
            case .japanese:
                SeedData.japaneseOnboardingNotes()
            }
        }

        static let english = LocalizedSeedContent(
            language: .english,
            collectionNames: ["Start Here", "Guide", "AI", "Journal", "Unorganized", "Import"],
            welcomeTitle: "Welcome to MindVault",
            graphTitle: "Explore with the Graph",
            aiTitle: "Use AI Organization",
            aiSummary: "This is the entry note for learning the basic MindVault flow.",
            aiSuggestedTags: ["GettingStarted", "Guide"],
            aiSuggestedCollection: "Start Here"
        )

        static let japanese = LocalizedSeedContent(
            language: .japanese,
            collectionNames: ["はじめに", "使い方", "AI活用", "日記", "未整理", "インポート"],
            welcomeTitle: "MindVaultへようこそ",
            graphTitle: "グラフで探す",
            aiTitle: "AI整理を使う",
            aiSummary: "MindVaultの基本操作へ進むための入口メモです。",
            aiSuggestedTags: ["はじめに", "使い方"],
            aiSuggestedCollection: "はじめに"
        )
    }
}
