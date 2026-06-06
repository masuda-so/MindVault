# MindVault AI / マインドヴォルトAI MVP

## MVP仕様書

MindVault AIは、ユーザーが自由に書いたMarkdownメモをローカル優先で保存し、オンデバイスAIとリンク解析で知識ネットワークとして扱うiOS/iPadOSアプリです。MVPは外部AIや独自サーバーを使わず、SwiftData、Natural Language、Foundation Models、StoreKit 2の導線で構成します。

対象ユーザーは、学習記録、日記、会議メモ、調査メモ、プロダクトアイデアを雑に書き溜めたい個人ユーザーと、小規模チーム導入前に個人ナレッジベースを育てたいPro候補ユーザーです。

## Obsidianとの差別化

MindVault AIはObsidian vault互換を出口として持ちますが、Obsidian代替のMarkdownエディタではなく、ユーザーが書いた断片を「なぜつながるのか」まで説明するオンデバイス知識マップを主価値にします。

差別化の軸:
- 説明可能なグラフ: エッジを明示リンク、Markdownリンク、AI提案、共通タグに分け、選択中ノードの周辺に「つながる理由」を表示する。
- ノイズを抑えた初期表示: 初期状態では明示リンクとAI提案を中心に表示し、弱いタグ共起はユーザーが必要なときだけ追加する。
- 承認制AI整理: AIは勝手に本文を書き換えず、タイトル、タグ、関連メモを提案し、ユーザー承認後に反映する。
- ローカル優先の信頼: Foundation Modelsとローカル埋め込みを使い、外部AIや分析送信に依存しない。

次フェーズでは、AI提案エッジに信頼度、根拠文、承認/却下の学習履歴を持たせ、単なるリンク可視化ではなく「自分の思考を育てるレビュー画面」に近づけます。

MVPの成功条件:
- 起動直後にグラフビューが表示され、ノードタップで該当メモに移動できる。
- Markdown本文、タグ、リンク、AIメタデータ、埋め込み、課金権限が分離保存される。
- `[[wiki link]]` とMarkdownリンクから双方向リンク/バックリンクを再構築できる。
- AI対象トグルがオフのメモは整理、埋め込み、AIチャット検索から除外される。
- Foundation Modelsが利用できる環境ではAI整理/チャット検索を実行し、利用不可時は理由を明示してクラウド送信しない。
- Free/Pro/Teamのサブスクリプション導線があり、Freeの月間AI整理制限を表現できる。

## 画面設計

アプリはSwiftUI `NavigationSplitView` を基本にします。iPadでは左からサイドバー、メモ一覧、ワークスペースの構成です。ワークスペースは初期状態でグラフビューを表示し、編集時は中央にMarkdownエディタ、右にAI提案/関連メモ/プライバシー/インポート・エクスポートを表示します。iPhoneではTabViewで「グラフ」「メモ」「検索」「設定」を表示し、グラフタブを初期選択します。

主要画面:
- グラフビュー: ノード、明示リンク、AI関連、タグ共起リンクをCanvasで描画。パン、ズーム、タップ選択に対応。
- メモエディタ: Markdown raw textを編集し、自動保存、タグ表示、プレビュー、バックリンクを表示。
- AI提案: タイトル、要約、タグ、コレクション、未解決リンク、関連メモを提案し、適用/編集/却下できる。未整理メモは一覧からまとめてAI整理キューへ送れる。
- AIチャット検索: ローカル埋め込みで候補ノートを選び、Foundation Modelsが利用可能な場合だけ回答を生成。
- 設定・プラン: Free/Pro/Team、AI利用量、StoreKitサブスクリプション導線、プライバシー方針を表示。

## データベース設計

SwiftDataモデル:
- `Note`: タイトル、コレクション、作成/更新日時、AI対象、日次メモ、タグ、AI利用回数。
- `NoteContent`: raw Markdown本文、文字数、単語数。
- `Tag`: タグ名、色、利用数。
- `NoteCollection`: コレクション名、説明、アイコン、並び順。
- `NoteLink`: source、target、raw target、表示文字列、リンク種別。
- `GraphEdge`: AI関連やタグ共起など、保存可能なグラフエッジ。
- `NoteAIMetadata`: AI提案のタイトル、要約、タグ、分類、関連ID、未解決リンク、状態。
- `AIJob`: 非同期AI整理ジョブの状態、開始/完了日時、エラー。
- `NoteEmbedding`: Natural Languageローカル埋め込みベクトル、モデルID、本文ハッシュ。
- `SubscriptionEntitlement`: Free/Pro/Team、月間AI利用、追加クレジット、ストレージ枠。

Markdown互換性:
- 本文はraw Markdownとして保持する。
- Markdown exportはYAML frontmatter + 本文で出力し、Obsidian vault移行を想定する。
- CSV/JSON exportは同じSwiftDataモデルから生成する。

## AI整理フロー設計

1. メモ編集後、自動保存が実行される。
2. Markdown解析でタグ、wikiリンク、Markdownリンクを抽出し、リンクインデックスを再構築する。
3. AI対象メモだけNatural Languageでローカル埋め込みを更新する。
4. AI対象、Foundation Models利用可能、月間AI整理残数あり、直近整理から一定時間経過の条件を満たす場合に `AIJob` を投入する。
5. `LanguageModelSession` と `@Generable` 構造化出力で整理案を生成する。関連候補として渡す既存ノートはAI対象メモだけに限定する。
6. 提案は `NoteAIMetadata` にdraftとして保存し、ユーザーの承認まで本文やタグへ反映しない。
7. 適用時にタイトル、タグ、コレクションを更新し、却下時は状態だけ更新する。

Foundation Modelsが利用不可の場合:
- 利用不可理由をUIに表示する。
- 外部AIやクラウド送信にはフォールバックしない。
- 通常検索、リンク解析、グラフ表示、Markdown編集は継続する。

## グラフビュー設計

グラフは `GraphBuilder` が以下のソースから構築します。
- 明示リンク: `[[wiki link]]` とMarkdownリンク。
- AI関連: AI整理結果の関連メモID。
- タグ共起: 重要タグを共有するノート間の弱いリンク。`使い方`、`未整理`、`AI活用` のような汎用タグは、過剰なエッジを避けるため共起リンクから除外する。

表示仕様:
- SwiftUI `Canvas` でノードとエッジを描画する。
- ノードの大きさは次数、色は状態/タグ/AI対象で変える。
- エッジ色はリンク種別で分ける。
- 右サイドバーにリンク種別ごとの説明付きトグルを表示する。
- 選択ノードのパネルに、表示中エッジの相手ノートと接続理由を表示する。
- 初期表示では明示リンク、Markdownリンク、AI関連のみを表示し、タグ共起は非表示にする。
- パン、ズーム、ノードタップを実装する。
- タップしたノードは選択状態にし、エディタへ移動する。

## 課金プラン設計

買い切りではなくサブスクリプションを前提にします。

| プラン | 価格 | MVPでの扱い | 主な価値 |
| --- | --- | --- | --- |
| Free | $0 | デフォルト | ローカルメモ、Markdown編集、月間AI整理200回 |
| Pro | 月額 | StoreKit導線 | AI整理10K回、CloudKit同期導線、高度グラフ、AIチャット検索 |
| Team | 月額/ユーザー | StoreKit導線 | 共有ナレッジベース、共同編集、管理者機能 |

将来の収益化候補（内部メモ）:
- AI処理クレジット
- ストレージ容量追加
- 企業向けオンプレミス契約

MVPではStoreKit 2 `SubscriptionStoreView` と商品IDプレースホルダを実装し、本番商品登録後に接続します。ローカル検証用に `MindVault/Configuration/MindVault.storekit` を共有SchemeのRun actionへ設定しています。

## テスト計画

Unit tests:
- Markdownタグ/wikiリンク/Markdownリンク抽出。
- リンク再構築とバックリンク。
- Markdown/JSON/CSV export形状。
- AI対象外ノートの埋め込み/検索除外。
- AI整理時の関連候補/関連IDからAI対象外ノートを除外。
- Freeプラン月間AI整理制限。

Service tests:
- `AIJobQueue` のqueued/running/completed/failed/skipped相当の状態遷移。
- Stub organizerによるAI提案の保存、適用、却下。
- グラフの明示リンク/タグ共起エッジ生成。
- 汎用タグだけではタグ共起エッジを生成しない。
- 埋め込みランキング。

UI tests:
- 初回起動でグラフが表示される。
- グラフノードからサンプルノートを開ける。
- iPhoneエディタからAI提案パネルを開き、未整理メモパネルを確認する。
- 今後、AI提案適用、検索、タグ/日付フィルター、課金画面表示を追加する。

検証コマンド:
- `build_sim` with scheme `MindVault` succeeded on iOS Simulator.
- `build_sim` with scheme `MindVault` succeeded on iPad Pro 13-inch (M5) Simulator after graph filter and symbol cleanup changes.
- `xcodebuild ... -only-testing:MindVaultTests/MindVaultCoreTests test` succeeded: 9 unit/service tests passed.
- `test_sim -only-testing:MindVaultTests` completed through XCTest: 20 tests executed, 0 failures. The tool wrapper timed out while collecting status, but the log ended with `** TEST EXECUTE SUCCEEDED **`.
- `xcodebuild ... -only-testing:MindVaultUITests/MindVaultUITests/testLaunchShowsGraphFirstAndCanOpenAIInspector test` succeeded: initial graph, graph-node navigation, AI proposal sheet, and unorganized-note panel verified by XCTest.
- `xcodebuild ... build-for-testing` succeeded and compiled `MindVault`, `MindVaultTests`, and `MindVaultUITests`.
- `MindVault/Configuration/MindVault.storekit` includes local Pro/Team auto-renewable subscriptions plus AI credit and storage consumables for StoreKit Testing; JSON validation and simulator build/run succeeded with the scheme reference in place.
- UIはiPhone Simulatorにインストール/起動し、起動直後のグラフビュー、ノート詳細、AI提案シート、未整理メモパネルをスクリーンショットで確認済み。
- UIはiPad Simulatorでも起動し、サイドバー、メモ一覧、グラフワークスペースの3ペイン構成をスクリーンショットで確認済み。
- 共有SchemeのTestActionはUI test runnerを安定させるため、デバッガなし/非並列のテスト起動に設定している。

## セキュリティ・プライバシー設計

MVPの原則:
- ローカル保存をデフォルトにする。
- AI処理はFoundation Modelsオンデバイス限定にする。
- AI対象トグルがオフのノートは整理、埋め込み、関連候補、AIチャット検索に含めない。
- CloudKit同期、Team共有、オンプレミス契約は次フェーズの拡張ポイントとしてUI/設計に留める。
- 外部AI、独自サーバー、分析送信はMVPに含めない。

将来のクラウド同期時に必要な追加設計:
- CloudKit private databaseを基本にし、Teamでは共有DB/共有ゾーンを分離する。
- ノート本文、AIメタデータ、埋め込み、課金情報の同期範囲を明確にする。
- Team管理者には監査ログ、メンバー権限、共有停止、データエクスポートを提供する。
