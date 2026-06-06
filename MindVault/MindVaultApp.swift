//
//  MindVaultApp.swift
//  MindVault
//
//  Created by 増田創 on 2026/05/30.
//

import SwiftUI
import SwiftData

@main
struct MindVaultApp: App {
    @State private var aiJobQueue = AIJobQueue()
    @State private var subscriptionService = SubscriptionService()

    private var sharedModelContainer: ModelContainer = {
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
        if let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        }
        let usesInMemoryStore = ProcessInfo.processInfo.arguments.contains("-MindVaultUseInMemoryStore")
            || ProcessInfo.processInfo.isRunningAppHostedUnitTests
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: usesInMemoryStore)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create MindVault SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .environment(aiJobQueue)
                .environment(subscriptionService)
        }
    }
}

extension ProcessInfo {
    var isRunningAppHostedUnitTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}
