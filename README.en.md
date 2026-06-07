# MindVault

![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4-blue)
![SwiftData](https://img.shields.io/badge/SwiftData-1.0-green)
![Platform](https://img.shields.io/badge/iOS%2F%2FiPadOS-17.0%2B-lightgrey)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

A local-first Markdown notebook that stores notes primarily on device and builds an explainable knowledge graph from links, tags, and on-device AI suggestions.

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

## User Flow

1. Launch into the **knowledge graph**.
2. Tap nodes to browse related notes.
3. Edits, links, and tags refresh graph connections.
4. AI suggestions are proposed per note and applied only after approval.
5. Settings expose plan usage, privacy, and StoreKit subscription options.

## Development

### Requirements

- Xcode 15+
- iOS Simulator or physical iOS device
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

## Current Status

- App Store Connect submission is being prepared (`PREPARE_FOR_SUBMISSION`).
- Initial submission is planned to attach `mindvault.pro.monthly` and `mindvault.team.monthly` to the app version.
- See `Docs/` for submission details and review notes.

## License

MIT
