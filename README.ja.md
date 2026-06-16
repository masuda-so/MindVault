# MindVault

![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4-blue)
![SwiftData](https://img.shields.io/badge/SwiftData-1.0-green)
![Platform](https://img.shields.io/badge/iOS%2F%2FiPadOS-17.0%2B-lightgrey)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

Markdown メモをローカル優先で保存し、リンクやタグ、オンデバイス AI で知識グラフを育てる個人用ノートアプリです。

> **Note**
> 英語版 README は [README.en.md](README.en.md) にあります。

## 特徴

- Markdownメモの作成と編集
- `[[wiki link]]` とMarkdownリンクによるメモ間リンク
- タグ、明示リンク、AI提案を使った知識グラフ
- ノードをタップして関連メモへ移動
- ローカル検索とAIチャット検索の導線
- Apple Foundation Models を使ったオンデバイスAI整理（対応デバイス）
- AI対象外にしたメモを整理、埋め込み、関連候補、AI検索から除外
- Markdown / JSON / CSV のインポート・エクスポート導線
- 広告なし

## アーキテクチャ

### 主要フレームワーク

- **SwiftUI** — クロスプラットフォーム UI（iPhone のタブ切り替え / iPad の 3 ペイン、`NavigationSplitView`）
- **SwiftData** — ローカル永続化（ノート、メタデータ、グラフ、埋め込み、課金権限）
- **Foundation Models** — オンデバイス AI（要約、タグ提案、関連メモ候補、チャット検索）
- **Natural Language** — ローカル埋め込み生成とセマンティック検索
- **StoreKit 2** — Free / Pro / Team の自動更新サブスクリプション
- **PDFKit / QuickLook** — PDF インポート（P3.6）

### データモデル

| モデル | 役割 |
| --- | --- |
| `Note` + `NoteContent` | タイトル、Markdown 本文、タグ、AI 対象フラグ等 |
| `NoteLink` | wiki/Markdown/AI/タグ共起リンク |
| `GraphEdge` | グラフ表示用エッジ（リンク種別・重み） |
| `NoteAIMetadata` | AI 提案（タイトル/要約/タグ/関連ノート） |
| `AIJob` | 非同期 AI 整理ジョブの状態管理 |
| `NoteEmbedding` | オンデバイス埋め込みベクトル |
| `SubscriptionEntitlement` | プラン、月間利用数、クレジット、ストレージ |

## プライバシーとデータ

- メモは**ローカル保存がデフォルト**です。
- ノート本文は外部 AI サービスや開発者サーバーに送信しません。
- AI 機能は対応デバイスでのみ実行され、利用不可時はその旨を UI に表示します。
- AI 対象をオフにしたメモは、AI 整理・埋め込み・関連候補・AI チャット検索から完全に除外されます。
- 広告は表示されません。

## プラン

MindVault はサブスクリプションを前提に設計されています。

| | Free | Pro | Team |
| --- | --- | --- | --- |
| 価格 | $0 | 月額 | 月額 / ユーザー |
| AI 整理の上限（月間） | 200 | 10,000 | 50,000 |
| AI チャット検索 | ✕ | ○ | ○ |
| 高度グラフ | ✕ | ○ | ○ |
| クラウド同期（将来） | — | 導線あり | 共有 DB |
| 管理機能 | — | — | ○ |

将来的には AI クレジットやストレージ追加などの拡張も想定しています。

## アプリの流れ

1. 起動直後に**知識グラフ**が表示されます。
2. ノードをタップすると、関連メモの詳細を開けます。
3. ノート一覧から Markdown を編集すると、リンクとタグが更新されグラフへ反映されます。
4. AI 整理はノードごとに実行され、提案の承認・却下で価値が蓄積します。
5. 設定からプランや AI 利用量、プライバシー方針を確認できます。

## 開発

### 前提

- Xcode 15 以降
- iOS Simulator または macOS デバイス
- StoreKit ローカル検証用: `MindVault/Configuration/MindVault.storekit`

### ビルドと実行

```bash
# クリーン
xcodebuild clean -project MindVault.xcodeproj -scheme MindVault -configuration Debug

# シミュレータービルド
xcodebuild build -project MindVault.xcodeproj -scheme MindVault -configuration Debug -sdk iphonesimulator
```

### テスト

```bash
# Unit / Service tests
xcodebuild test \
  -project MindVault.xcodeproj \
  -scheme MindVault \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# UI test（例）
xcodebuild test \
  -project MindVault.xcodeproj \
  -scheme MindVault \
  -only-testing:MindVaultUITests/MindVaultUITests/testLaunchShowsGraphFirstAndCanOpenAIInspector
```

## 現在の状態

- App Store Connect への提出準備中（`PREPARE_FOR_SUBMISSION`）
- 初回提出では、サブスクリプション（`mindvault.pro.monthly`, `mindvault.team.monthly`）をアプリバージョンに添付する予定です。
- 現行ドキュメントは `Docs/` を参照してください。

## ライセンス

MIT
