# MindVault

[English](README.en.md) · [日本語](README.ja.md)

![Platform](https://img.shields.io/badge/Platform-iOS%20%2F%20iPadOS%2017.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-SwiftUI%20%7C%20SwiftData-orange)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

A local-first Markdown notebook that stores notes primarily on device and builds an explainable knowledge graph from links, tags, and on-device AI suggestions.

---

## About

**MindVault** is a local-first Markdown notebook for people who want their ideas to grow. Write in plain Markdown, link any two notes together, and your knowledge turns into an explainable graph you can explore — with on-device AI that suggests what to read next.

## Key Features

- Markdown authoring with live autosave
- `[[wiki link]]` and Markdown links with backlink reconstruction
- Knowledge graph built from explicit links, AI suggestions, and tag cooccurrence
- Tap graph nodes to open related notes
- Local search and AI chat search
- On-device AI organization via Apple Foundation Models when supported
- AI-eligible toggle to exclude notes from organization, embeddings, candidates, and chat search
- Markdown / JSON / CSV import and export
- No ads

## Architecture

### Frameworks

- **SwiftUI** — cross-platform UI (iPhone tab flow / iPad 3-pane `NavigationSplitView`)
- **SwiftData** — local persistence for notes, metadata, graphs, embeddings, and entitlements
- **Foundation Models** — on-device AI (summaries, tags, related-note candidates, chat)
- **Natural Language** — local embeddings and semantic search
- **StoreKit 2** — Free / Pro / Team auto-renewable subscriptions
- **PDFKit / QuickLook** — PDF import (P3.6)

### Data Models

| Model | Responsibility |
| --- | --- |
| `Note` + `NoteContent` | Title, Markdown body, tags, AI-eligible flag |
| `NoteLink` | wiki, Markdown, AI, and tag-cooccurrence links |
| `GraphEdge` | Graph edges by kind and weight |
| `NoteAIMetadata` | Draft AI suggestions: title, summary, tags, related IDs |
| `AIJob` | Async AI organization job state machine |
| `NoteEmbedding` | On-device embedding vectors |
| `SubscriptionEntitlement` | Plan, monthly usage, credits, storage |

## Privacy

- Notes are stored locally by default.
- Note content is not sent to external AI services or custom servers.
- On-device AI runs only on supported devices; unsupported states are shown in UI with no cloud fallback.
- Notes with AI disabled are fully excluded from AI flows.
- No ads.

## Plans

Subscriptions are Free / Pro / Team.

| | Free | Pro | Team |
| --- | --- | --- | --- |
| Price | $0 | Monthly | Per-user monthly |
| Monthly AI organize limit | 200 | 10,000 | 50,000 |
| AI chat search | ✕ | ○ | ○ |
| Advanced graph | ✕ | ○ | ○ |
| Cloud sync (future) | — | Planned | Shared DB |
| Admin controls | — | — | ○ |

Future extensions may include AI credits and extra storage tiers.

## Getting Started

### Requirements

- Xcode 15 or later
- iOS Simulator or a physical iOS device
- Local StoreKit testing: `MindVault/Configuration/MindVault.storekit`

### Build and Run

```bash
# Clean
xcodebuild clean -project MindVault.xcodeproj -scheme MindVault -configuration Debug

# Simulator build
xcodebuild build -project MindVault.xcodeproj -scheme MindVault -configuration Debug -sdk iphonesimulator
```

### Tests

```bash
# Unit / Service tests
xcodebuild test \
  -project MindVault.xcodeproj \
  -scheme MindVault \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# UI test example
xcodebuild test \
  -project MindVault.xcodeproj \
  -scheme MindVault \
  -only-testing:MindVaultUITests/MindVaultUITests/testLaunchShowsGraphFirstAndCanOpenAIInspector
```

## Usage

1. Launch into the **knowledge graph**.
2. Tap nodes to browse related notes.
3. Edits, links, and tags refresh graph connections.
4. AI suggestions are proposed per note and applied only after approval.
5. Settings expose plan usage, privacy, and StoreKit subscription options.

## Status

Preparing for App Store Connect submission (`PREPARE_FOR_SUBMISSION`). The initial submission is planned to attach `mindvault.pro.monthly` and `mindvault.team.monthly` to the app version. See `Docs/` for submission details and review notes. GitHub Pages is intentionally disabled for this source repository.

## Support

- Questions or bug reports: open a [GitHub Issue](https://github.com/masuda-so/MindVault/issues)
- Email: so.masuda.2003@pm.me

## License

Licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.

## Maintainer

- **Soh Masuda** (増田創) — original developer

Contributions are welcome. See [CONTRIBUTING](./CONTRIBUTING.md).
