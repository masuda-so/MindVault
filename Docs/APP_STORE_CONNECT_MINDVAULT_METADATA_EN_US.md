# MindVault App Store Connect Metadata - English (U.S.) Candidate

Prepared: 2026-06-21

This is a local candidate only. It has not been saved to App Store Connect.

## Evidence Used

- Existing MindVault Japanese metadata draft: `docs/APP_STORE_CONNECT_MINDVAULT_METADATA.md`
- Current app copy and product scope: `README.en.md`, `README.ja.md`
- Existing translated reference app structure and tone:
  - `/Users/masudaso/Documents/GitHub/GratefulMoments/AppStoreConnectAssets/ja-JP/metadata.md`
  - `/Users/masudaso/Documents/GitHub/GratefulMoments/AppStoreConnectAssets/en-US/metadata.md`
- App-side localization check:
  - `MindVault.xcodeproj/project.pbxproj` uses `developmentRegion = en`
  - known regions are `en`, `Base`, and `ja`
  - `MindVault/Resources/Localizable.xcstrings` uses `sourceLanguage = en`

## App Information

- Locale: English (U.S.)
- App Name: MindVault
- Subtitle: Local notes, linked ideas
- Category: Productivity
- Secondary Category: Utilities
- Copyright: 2026 Ether LLC

## URLs

- Privacy Policy URL: https://masuda-so.github.io/MindVault/privacy/
- Support URL: https://masuda-so.github.io/MindVault/support/
- Marketing URL: https://masuda-so.github.io/MindVault/

## Promotional Text

Write Markdown notes, link ideas, and explore your private knowledge graph with on-device AI. No ads, with notes stored locally by default.

## Description

MindVault is a local-first Markdown notebook for seeing how your ideas connect.

Open the app and start from a knowledge graph of your notes. Write meeting notes, research fragments, journal entries, project plans, and reading notes, then use links, tags, and on-device AI suggestions to make relationships easier to follow.

Key features:
- Create and edit Markdown notes
- Link notes with `[[wiki link]]` and Markdown links
- Explore a knowledge graph built from explicit links, AI suggestions, and shared tags
- Tap graph nodes to open related notes
- Use local search and AI chat search paths
- Organize notes with Apple Foundation Models on supported devices
- Exclude selected notes from AI organization, embeddings, related-note candidates, and AI chat search
- Import and export Markdown, JSON, and CSV
- Use the app with no ads

Notes are stored locally by default. MindVault does not send note content to an external AI service or custom server. If on-device AI is unavailable, the app still supports note editing, link analysis, graph viewing, and local search.

Optional Pro and Team subscriptions expand AI organization limits, AI chat search, and advanced graph features through StoreKit.

MindVault is made for people who want a private, structured place to write notes and revisit how their thinking develops over time.

Terms of Use (Apple Standard EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

## Keywords

markdown,notes,knowledge graph,local AI,wiki links,search,journal,productivity,private

## What's New

MindVault 1.0 is the first release, with Markdown notes, a knowledge graph, local search, import and export paths, and on-device AI organization.

## App Review Notes Candidate

App Review notes are not locale-specific. Use this only if the review detail needs an English refresh; do not overwrite the currently selected build or existing review notes without confirming the active App Store Connect state first.

Updated build for App Review: MindVault 1.0 build 5.

This build addresses the previous App Review feedback:

1. Guideline 2.1(b)
The Paid Apps Agreement for Ether LLC is active in App Store Connect Business. The MindVault auto-renewable subscription products are configured with pricing and availability and currently show Waiting for Review:
- mindvault.pro.monthly
- mindvault.team.monthly

The subscription screen uses Apple's StoreKit SubscriptionStoreView with the production product identifiers above. Build 5 also removes the previous development-only explanatory copy from the paywall so reviewers see the production purchase path.

Reviewer path: open MindVault, go to the Settings tab, then the Current Plan section. Choose a monthly plan from the StoreKit subscription options.

2. Guideline 3.1.2(c)
The subscription screen now includes visible policy links inside the app:
- Privacy Policy: https://masuda-so.github.io/MindVault/privacy/
- Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Reviewer path: open MindVault, go to the Settings tab, then the Current Plan section. The SubscriptionStoreView also exposes StoreKit policy buttons.

3. Guideline 3.1.1
The app now includes a distinct Restore Purchases button on the subscription screen. It calls StoreKit AppStore.sync() and refreshes verified transactions.

Reviewer path: open MindVault, go to Settings, then Current Plan, then tap Restore Purchases.

No demo account is required. MindVault works locally with sample/on-device content and StoreKit handles purchases.

## App-Side Localization Assessment

- App UI source language is English (`en`), not Japanese-only.
- Japanese UI localization is present through `Localizable.xcstrings`.
- A separate `en-US` app resource is not currently required because English strings are the source language and Xcode project regions already include `en`.
- App Store Connect `en-US` metadata support is separate from app UI localization and still requires creating/saving the `en-US` locale in App Store Connect.

## User Confirmation Needed Before External Changes

- Create or enable the `en-US` App Store localization for MindVault in App Store Connect.
- Save the English (U.S.) metadata above to App Store Connect.
- Replace or update App Review notes.
- Submit for review or change any build/subscription review state.
