# MindVault App Store Connect Metadata

作成日: 2026-06-05

## 現在の App Store Connect 状態

- App ID: `6776897058`
- App name: `MindVault`
- Bundle ID: `ether.gk.MindVault`
- iOS version: `1.0`
- App Store version ID: `9f074ce3-67e3-4dc0-98b4-e6a92b0893e6`
- 日本語 localization ID: `0ef30351-d1ba-41ab-81ee-b20b8105a4ff`
- Build: `1`
- Build ID: `3f45871a-71e9-4d7f-b386-db229b3dc6cd`
- Build processing state: `VALID`
- Current state: `PREPARE_FOR_SUBMISSION`

## 参考元との比較

`小さなありがとう日記` では、少なくとも以下が入力済みだった。

- iPhone / iPad スクリーンショット
- 概要
- このバージョンの最新情報
- キーワード
- サポートURL
- マーケティングURL
- 著作権
- ビルド
- App Review 情報
- App Store バージョンのリリース方法
- プライバシーポリシーURL
- 年齢制限回答
- サブスクリプション商品とレビュー用メモ

## MindVault の不足項目

- 日本語 metadata:
  - 概要
  - このバージョンの最新情報
  - キーワード
  - サポートURL
  - マーケティングURL
- App Info:
  - サブタイトル
  - カテゴリ
  - プライバシーポリシーURL
- App Review:
  - 連絡先情報
  - レビューメモ
- Trust and Safety:
  - App Privacy questionnaire
  - 年齢制限回答
  - 暗号化回答
- Monetization:
  - App Store Connect 本番側に subscription group / IAP は未作成。

## スクリーンショット素材

作成済み:

- `AppStoreAssets/Screenshots/iPhone/01-graph.png` (`1320x2868`)
- `AppStoreAssets/Screenshots/iPhone/02-notes.png` (`1320x2868`)
- `AppStoreAssets/Screenshots/iPhone/03-search.png` (`1320x2868`)
- `AppStoreAssets/Screenshots/iPhone/04-settings-plan.png` (`1320x2868`)
- `AppStoreAssets/Screenshots/iPad/01-ipad-graph.png` (`2064x2752`)

App Store Connect upload target:

- iPhone: `APP_IPHONE_65`
- iPad: `APP_IPAD_PRO_3GEN_129`

## 推奨 metadata

### サブタイトル

思考をつなぐ知識グラフノート

### プロモーション用テキスト

Markdownメモを起動直後の知識グラフで見渡せます。リンク、タグ、オンデバイスAI提案を使い、考えのつながりをローカル優先で育てるノートアプリです。

### 概要

MindVaultは、Markdownメモをローカル優先で保存し、リンクやタグ、オンデバイスAIの提案を知識グラフとして見渡せる個人用ノートアプリです。

起動するとすぐにグラフビューが表示され、メモ同士のつながりを視覚的に確認できます。思いつき、調査メモ、会議メモ、学習記録、日記の断片をためながら、「なぜこのメモがつながるのか」を追いやすい形で整理できます。

主な機能:
・Markdownメモの作成と編集
・[[wiki link]] とMarkdownリンクによるメモ間リンク
・タグ、明示リンク、AI提案を使った知識グラフ
・ノードをタップして関連メモへ移動
・ローカル検索とAIチャット検索の導線
・対応デバイスでは Apple Foundation Models を使ったオンデバイスAI整理
・AI対象外にしたメモを整理、埋め込み、関連候補、AI検索から除外
・Markdown / JSON / CSV のインポート・エクスポート導線
・広告なし

メモ本文はローカル保存を基本とし、外部AIサービスや独自サーバーへ送信しません。オンデバイスAIが利用できない環境では、通常のメモ編集、リンク解析、グラフ表示、ローカル検索をそのまま利用できます。

MindVaultは、メモをただ保存するだけでなく、自分の考えがどのようにつながっているかを見直したい人のための知識ノートです。

利用規約（Apple標準EULA）: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

### このバージョンの最新情報

MindVault 1.0 の初回リリースです。Markdownメモ、知識グラフ、ローカル検索、オンデバイスAI整理の導線を追加しました。

### キーワード

メモ,ノート,Markdown,知識グラフ,AI整理,オンデバイスAI,ローカル保存,リンク,タグ,検索,アイデア,日記,学習,仕事

### カテゴリ

- Primary category: `PRODUCTIVITY`
- Secondary category: `UTILITIES` または `REFERENCE`

### 著作権

2026 Ether LLC

## App Review 情報案

This app does not require sign-in.

MindVault is a local-first Markdown note and knowledge graph app. Users can create Markdown notes, link notes with wiki links or Markdown links, view an explainable graph of note relationships, and use on-device organization features when supported by the device.

Privacy and AI behavior:

- User notes are stored locally by default.
- The app does not send note content to an external AI service or custom server.
- On-device AI features use Apple Foundation Models only when available.
- If on-device AI is unavailable, the app shows an unavailable state and continues to support note editing, graph viewing, and local search.
- Notes marked as AI-ineligible are excluded from AI organization, embeddings, related-note candidates, and AI chat search.
- The app does not include ads.

Review steps:

1. Launch the app.
2. Confirm that the graph view is visible on launch.
3. Tap a graph node to open the related Markdown note.
4. Open the Notes tab and create or edit a Markdown note.
5. Add a wiki link such as `[[MindVaultへようこそ]]` or a Markdown link, then return to the graph to confirm that explicit links are reflected.
6. Open the Search tab and confirm that local note candidates are shown.
7. Open Settings and confirm the privacy explanation and plan information.
8. If the test device supports Apple Foundation Models, open the AI organization or AI chat search flow. If unsupported, confirm that the app shows an explanatory unavailable state and does not offer an external AI fallback.

## 年齢制限回答案

`小さなありがとう日記` と同等に、以下で問題ない見込み。

- advertising: `false`
- alcoholTobaccoOrDrugUseOrReferences: `NONE`
- contests: `NONE`
- gambling: `false`
- gamblingSimulated: `NONE`
- gunsOrOtherWeapons: `NONE`
- healthOrWellnessTopics: `false`
- lootBox: `false`
- medicalOrTreatmentInformation: `NONE`
- messagingAndChat: `false`
- parentalControls: `false`
- profanityOrCrudeHumor: `NONE`
- ageAssurance: `false`
- sexualContentGraphicAndNudity: `NONE`
- sexualContentOrNudity: `NONE`
- horrorOrFearThemes: `NONE`
- matureOrSuggestiveThemes: `NONE`
- unrestrictedWebAccess: `false`
- userGeneratedContent: `false`
- violenceCartoonOrFantasy: `NONE`
- violenceRealisticProlongedGraphicOrSadistic: `NONE`
- violenceRealistic: `NONE`

## 提出前ブロッカー

### 1. サポートURL / プライバシーURL

App Store Connect では公開済みURLが必要。現時点では MindVault 用の公開 GitHub Pages / サポートページを確認できていない。

推奨URL例:

- Marketing: `https://masuda-so.github.io/MindVault/`
- Support: `https://masuda-so.github.io/MindVault/support/`
- Privacy: `https://masuda-so.github.io/MindVault/privacy/`

ただし、これらは実際に公開されるまで App Review に使わないこと。

### 2. 本番サブスクリプション未作成

App Store Connect には `mindvault.pro.monthly` / `mindvault.team.monthly` がまだ存在しない。

現行 build には `SubscriptionStoreView(productIDs:)` があり、商品未作成のまま提出すると StoreKit 商品が返らない可能性がある。

安全な選択肢:

1. Subscription-first で進める:
   - subscription group を作成
   - `mindvault.pro.monthly` と `mindvault.team.monthly` を作成
   - 価格、配信国、ローカリゼーション、レビュー用スクリーンショット、レビューメモを入力
   - 初回 iOS 1.0 submission に添付
2. Free MVP として先に提出する:
   - Release build で購入導線と未接続商品文言を非表示にする
   - build number を上げて再アップロード
   - App Store metadata から subscription unlock 表現を外す

現時点では 1 の方が当初方針に近いが、外部状態を大きく変更するため、実行前に明示確認が必要。

