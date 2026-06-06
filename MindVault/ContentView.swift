//
//  ContentView.swift
//  MindVault
//
//  Created by 増田創 on 2026/05/30.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MindVaultRootView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
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
        ], inMemory: true)
        .environment(AIJobQueue())
        .environment(SubscriptionService())
}
