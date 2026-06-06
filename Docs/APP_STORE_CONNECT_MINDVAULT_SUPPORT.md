# MindVault App Store Connect Support

作成日: 2026-06-05

## 現在わかっているローカル情報

- App name: MindVault AI / マインドヴォルトAI
- Bundle ID: `ether.gk.MindVault`
- Team ID: `L246T6JU9P`
- Version: `1.0`
- Build: `1`
- Product IDs:
  - `mindvault.pro.monthly`
  - `mindvault.team.monthly`
  - `mindvault.ai.credits.500`
  - `mindvault.storage.50gb`
- MVP policy:
  - Local-first note storage.
  - On-device AI through Apple Foundation Models only.
  - No external AI fallback.
  - No developer access to private note content.
  - Subscription-first monetization.

## App Store Connect 初回提出の重要順序

Apple の公式ヘルプ上、初回の In-App Purchase / subscription は、新しいアプリバージョンと一緒に提出する必要がある。MindVault では以下の順で進める。

1. App Store Connect で MindVault のアプリレコードを作成する。
2. Bundle ID `ether.gk.MindVault` を選ぶ。
3. iOS / iPadOS の `1.0` バージョンを作成する。
4. 本番のサブスクリプショングループを作成する。
5. `mindvault.pro.monthly` と `mindvault.team.monthly` を本番商品として登録し、ステータスを Ready to Submit にする。
6. 必要なら消耗型商品 `mindvault.ai.credits.500` と `mindvault.storage.50gb` は、MVP公開時に実際に販売するか再判断する。
7. Xcode から build `1` を archive/upload し、App Store Connect の Build section に反映されるのを待つ。
8. アプリバージョンの Build section で正しいビルドを選択する。
9. In-App Purchases and Subscriptions section で、初回提出対象のサブスクリプションをアプリバージョンに添付する。
10. App Review information にレビュー手順とプライバシー説明を書く。
11. Add for Review で draft submission に追加する。
12. 最終確認後に Submit for Review を押す。

## Apple Developer Support 問い合わせ文

### 日本語版

件名:
MindVault AI の初回 App Store Connect 提出と初回サブスクリプション添付手順についての確認

本文:

Apple Developer Support ご担当者様

お世話になっております。Ether LLC の増田創です。

現在、iOS / iPadOS アプリ「MindVault AI」の初回 App Store Connect 提出準備を進めています。初回提出時に自動更新サブスクリプションも同時に審査へ提出する予定のため、App Store Connect 上の正しい提出手順について確認させてください。

対象アプリ情報:

- App name: MindVault AI / マインドヴォルトAI
- Bundle ID: ether.gk.MindVault
- Version: 1.0
- Build: 1
- Team: Ether LLC
- Planned subscription product IDs:
  - mindvault.pro.monthly
  - mindvault.team.monthly

MindVault AI は、ユーザーが作成した Markdown メモをローカル優先で保存し、オンデバイスの Apple Foundation Models とリンク解析によって知識グラフとして整理するアプリです。外部 AI サービスや独自サーバーへの送信は行わず、ノート本文は原則として端末内に保存されます。アプリ内では Free / Pro / Team のプラン導線を用意し、Pro / Team は StoreKit 2 の自動更新サブスクリプションとして提供する予定です。

確認したい点は以下です。

1. 初回の自動更新サブスクリプションは、App Store Connect 上で Ready to Submit 状態にしたうえで、iOS 1.0 のアプリバージョン画面にある In-App Purchases and Subscriptions section から選択し、アプリバージョンと一緒に Submit for Review する、という理解で正しいでしょうか。
2. 初回提出時に `mindvault.pro.monthly` と `mindvault.team.monthly` の両方を同じ subscription group に入れ、同じ iOS 1.0 submission に添付して提出してよいでしょうか。
3. アプリバージョン画面に In-App Purchases and Subscriptions section が表示されない場合、または Ready to Submit の subscription をアプリバージョンに添付できない場合、App Store Connect 上で確認すべき不足項目や推奨される対応手順はありますでしょうか。
4. 初回提出でサブスクリプションを添付する前に、価格、配信国、ローカリゼーション、Review Screenshot、Review Notes 以外に、特に確認すべき項目があればご教示ください。

App Review の事前判断をお願いする意図ではなく、App Store Connect 上で初回アプリバージョンと初回自動更新サブスクリプションを正しく提出するための操作手順の確認です。

お手数をおかけしますが、ご確認のほどよろしくお願いいたします。

増田創
Ether LLC

### English version

Subject:
Confirming first App Store Connect submission flow for MindVault AI and initial auto-renewable subscriptions

Body:

Hello Apple Developer Support,

My name is So Masuda from Ether LLC.

I am preparing the first App Store Connect submission for an iOS / iPadOS app named "MindVault AI". Since this first app submission will also include the app's initial auto-renewable subscriptions, I would like to confirm the correct App Store Connect workflow before submitting.

App information:

- App name: MindVault AI
- Bundle ID: ether.gk.MindVault
- Version: 1.0
- Build: 1
- Team: Ether LLC
- Planned subscription product IDs:
  - mindvault.pro.monthly
  - mindvault.team.monthly

MindVault AI is a local-first Markdown note and knowledge graph app. It stores user-created notes primarily on device and uses on-device Apple Foundation Models and local link analysis to organize notes into an explainable knowledge graph. The app does not send note content to an external AI service or a custom server. The app includes Free / Pro / Team plan flows, and Pro / Team are planned as StoreKit 2 auto-renewable subscriptions.

Could you please confirm the following App Store Connect workflow questions?

1. For the first auto-renewable subscriptions for this app, is it correct that the subscriptions must be in Ready to Submit status and then selected from the In-App Purchases and Subscriptions section on the iOS 1.0 app version page before submitting the app version for review?
2. Is it acceptable to include both `mindvault.pro.monthly` and `mindvault.team.monthly` in the same subscription group and attach both to the same first iOS 1.0 submission?
3. If the In-App Purchases and Subscriptions section does not appear on the app version page, or if Ready to Submit subscriptions cannot be attached to the app version, what missing fields or App Store Connect setup items should I check first?
4. Before attaching the subscriptions to the first app version, are there any required setup items beyond price, availability, localization, review screenshot, and review notes that I should confirm?

I am not requesting a pre-approval of App Review content. I am only trying to confirm the correct operational steps in App Store Connect for submitting the first app version together with the first auto-renewable subscriptions.

Thank you for your help.

So Masuda
Ether LLC

## App Review information draft

This app does not require sign-in.

MindVault AI is a local-first Markdown note and knowledge graph app. Users can create Markdown notes, link notes with wiki links or Markdown links, view an explainable graph of note relationships, and use on-device AI organization features when supported by the device.

Privacy and AI behavior:

- User notes are stored locally by default.
- The app does not send note content to an external AI service or custom server.
- On-device AI features use Apple Foundation Models only when available.
- If on-device AI is unavailable, the app shows an unavailable state and continues to support note editing, graph viewing, and local search.
- Notes marked as AI-ineligible are excluded from AI organization, embeddings, related-note candidates, and AI chat search.

Subscription review steps:

1. Launch the app.
2. Confirm that the graph view is visible on launch.
3. Open Settings / Plan.
4. Confirm that Free / Pro / Team plan information is shown.
5. Open the subscription purchase flow.
6. Confirm that the Pro and Team subscription options load.
7. Open the note editor and create or edit a Markdown note.
8. Confirm that the graph updates based on explicit note links.
9. If the test device supports Apple Foundation Models, open the AI organization or AI chat search flow. If unsupported, confirm that the app shows an explanatory unavailable state and does not offer an external AI fallback.

## 管理メモ

- 最終提出、問い合わせ送信、ファイルアップロード、価格・配信国・サブスクリプション販売設定の保存は、実際に外部状態を変える操作なので、実行直前に確認を取る。
- App Store Connect 画面上で MindVault の app record が未作成なら、問い合わせ送信より先に app record 作成と Bundle ID の確認を行う。
- 初回サブスクリプションはアプリバージョンに添付して提出する。単体提出しようとして詰まった場合は、Apple Support への問い合わせで「初回サブスクリプションを app version に添付できない」ことを明確に伝える。

## 参考

- Apple Developer: Submit an app: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app
- Apple Developer: Submit an In-App Purchase: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase
- Apple Developer: Overview of submitting for review: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review
