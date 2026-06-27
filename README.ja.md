# MindVault

[English](README.en.md) · [日本語](README.ja.md)

![Platform](https://img.shields.io/badge/Platform-iOS%20%2F%20iPadOS%2017.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-SwiftUI%20%7C%20SwiftData-orange)
![License](https://img.shields.io/badge/License-Apache%202.0-lightgrey)

Markdown メモをローカル優先で保存し、リンクやタグ、オンデバイス AI で説明可能な知識グラフを育てる個人用ノートアプリ。

---

## アプリについて

**MindVault** は、アイデアを育てたい人のためのローカル優先 Markdown ノートアプリです。素の Markdown で書き、任意のメモ同士をリンクすると、知識が探索できるグラフになります。オンデバイス AI が「次に読むべきもの」を提案します。

## 主な機能

- Markdownメモの作成と編集（自動保存）
- `[[wiki link]]` とMarkdownリンクによるメモ間リンク（バックリンク復元）
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

## プライバシー

- メモは**ローカル保存がデフォルト**です。
- ノート本文は外部 AI サービスや開発者サーバーに送信しません。
- AI 機能は対応デバイスでのみ実行され、利用不可時はその旨を UI に表示します（クラウドへのフォールバックはありません）。
- AI 対象をオフにしたメモは、AI 整理・埋め込み・関連候補・AI チャット検索から完全に除外されます。
- 広告は表示されません。

## プラン

サブスクリプションは Free / Pro / Team です。

| | Free | Pro | Team |
| --- | --- | --- | --- |
| 価格 | $0 | 月額 | 月額 / ユーザー |
| AI 整理の上限（月間） | 200 | 10,000 | 50,000 |
| AI チャット検索 | ✕ | ○ | ○ |
| 高度グラフ | ✕ | ○ | ○ |
| クラウド同期（将来） | — | 導線あり | 共有 DB |
| 管理機能 | — | — | ○ |

将来的には AI クレジットやストレージ追加などの拡張も想定しています。

## 始め方

### 必要環境

- Xcode 15 以降
- iOS Simulator または実機
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

## 使い方

1. 起動直後に**知識グラフ**が表示されます。
2. ノードをタップすると、関連メモの詳細を開けます。
3. ノート一覧から Markdown を編集すると、リンクとタグが更新されグラフへ反映されます。
4. AI 整理はノードごとに実行され、提案の承認・却下で価値が蓄積します。
5. 設定からプランや AI 利用量、プライバシー方針を確認できます。

## 現在の状態

App Store Connect への提出準備中（`PREPARE_FOR_SUBMISSION`）です。初回提出では、サブスクリプション（`mindvault.pro.monthly`, `mindvault.team.monthly`）をアプリバージョンに添付する予定です。提出詳細は `docs/` を参照してください。本ソースリポジトリでは GitHub Pages を意図的に無効化しています。

## サポート

- 質問やバグ報告は [GitHub Issue](https://github.com/masuda-so/MindVault/issues) へ
- メール: so.masuda.2003@pm.me

## ライセンス

このプロジェクトは Apache License 2.0 の下で公開されています。詳細は [LICENSE](./LICENSE) を参照してください。

## メンテナー

- **増田創 (Soh Masuda)** — オリジナル開発者

コントリビューション歓迎です。[CONTRIBUTING](./CONTRIBUTING.md) を参照してください。
