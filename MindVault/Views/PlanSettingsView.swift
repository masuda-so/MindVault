import StoreKit
import SwiftData
import SwiftUI

struct PlanSettingsView: View {
    @Environment(SubscriptionService.self) private var subscriptionService
    @AppStorage("vaultAppearance") private var vaultAppearanceRawValue = VaultAppearance.system.rawValue
    @State private var restoreState = RestoreState.idle

    @Bindable var entitlement: SubscriptionEntitlement
    let notes: [Note]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                appearancePanel
                privacyPolicy
                planOverview
                subscriptionStore
            }
            .padding(16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .safeAreaPadding(.bottom, 16)
        .navigationTitle("Settings & Plan")
        .toolbarBackground(Color(uiColor: .systemBackground), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .task {
            await subscriptionService.refreshVerifiedEntitlement(entitlement)
        }
    }

    private var appearancePanel: some View {
        VaultPanel {
            VStack(alignment: .leading, spacing: 10) {
                Label("Appearance", systemImage: "paintpalette")
                    .font(.headline)

                Picker("Theme", selection: appearanceSelection) {
                    ForEach(VaultAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)

                Text("Current: \(currentAppearance.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var privacyPolicy: some View {
        VaultPanel {
            VStack(alignment: .leading, spacing: 10) {
                Label("Privacy", systemImage: "lock.shield")
                    .font(.headline)
                Text("The MVP is local-first and on-device AI only. Notes excluded from AI are not included in organization, embeddings, or AI chat search. CloudKit sync and Team sharing are designed for the next phase.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    stat(String(localized: "AI Enabled"), "\(notes.filter(\.isAIEligible).count)")
                    stat(String(localized: "Excluded"), "\(notes.filter { !$0.isAIEligible }.count)")
                    stat(String(localized: "Storage"), String(localized: "Local"))
                }
            }
        }
    }

    private var planOverview: some View {
        VaultPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Current Plan")
                        .font(.headline)
                    Spacer()
                    PlanBadge(plan: entitlement.plan)
                }

                #if DEBUG
                Picker("Debug Plan", selection: $entitlement.plan) {
                    ForEach(SubscriptionPlan.allCases) { plan in
                        Text(plan.displayName).tag(plan)
                    }
                }
                .pickerStyle(.segmented)

                Text("For local verification in Debug builds only. Release builds update the plan from verified StoreKit transactions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #else
                Text("The plan is updated from verified StoreKit transactions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif

                AIUsageMeter(entitlement: entitlement)

                VStack(alignment: .leading, spacing: 8) {
                    planFeatureRow(plan: "Free", detail: String(localized: "Local notes, basic editing, and monthly AI organization limits"))
                    planFeatureRow(plan: "Pro", detail: String(localized: "More AI organization, CloudKit sync path, advanced graph, and AI chat search"))
                    planFeatureRow(plan: "Team", detail: String(localized: "Collaboration, shared knowledge bases, and room for admin features"))
                }
            }
        }
    }

    private var subscriptionStore: some View {
        VaultPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("StoreKit Subscriptions")
                    .font(.headline)
                SubscriptionStoreView(productIDs: [
                    SubscriptionService.proMonthlyProductID,
                    SubscriptionService.teamMonthlyProductID
                ]) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MindVault AI Pro / Team")
                            .font(.headline)
                        Text("Choose a monthly plan to unlock higher AI organization limits, AI chat search, advanced graph features, and the Team roadmap.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 220)
                .storeButton(.visible, for: .restorePurchases, .policies)
                .subscriptionStorePolicyDestination(
                    url: SubscriptionService.privacyPolicyURL,
                    for: .privacyPolicy
                )
                .subscriptionStorePolicyDestination(
                    url: SubscriptionService.termsOfUseURL,
                    for: .termsOfService
                )

                purchaseSupportActions
            }
        }
    }

    private var purchaseSupportActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                restorePurchases()
            } label: {
                Label(restoreState.buttonTitle, systemImage: "arrow.clockwise.circle")
            }
            .buttonStyle(.bordered)
            .disabled(restoreState.isRestoring)
            .accessibilityIdentifier("restorePurchasesButton")

            if let message = restoreState.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(restoreState.isError ? .red : .secondary)
            }

            HStack(spacing: 14) {
                Link(destination: SubscriptionService.privacyPolicyURL) {
                    Label("Privacy Policy", systemImage: "lock.shield")
                }

                Link(destination: SubscriptionService.termsOfUseURL) {
                    Label("Terms of Use (EULA)", systemImage: "doc.text")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func planFeatureRow(plan: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(plan)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currentAppearance: VaultAppearance {
        VaultAppearance(rawValue: vaultAppearanceRawValue) ?? .system
    }

    private var appearanceSelection: Binding<VaultAppearance> {
        Binding(
            get: { currentAppearance },
            set: { vaultAppearanceRawValue = $0.rawValue }
        )
    }

    private func restorePurchases() {
        restoreState = .restoring
        Task {
            do {
                try await subscriptionService.restorePurchases(entitlement)
                restoreState = .restored
            } catch {
                restoreState = .failed(error.localizedDescription)
            }
        }
    }
}

private enum RestoreState: Equatable {
    case idle
    case restoring
    case restored
    case failed(String)

    var buttonTitle: LocalizedStringKey {
        switch self {
        case .idle, .restored, .failed:
            "Restore Purchases"
        case .restoring:
            "Restoring Purchases..."
        }
    }

    var message: LocalizedStringKey? {
        switch self {
        case .idle, .restoring:
            nil
        case .restored:
            "Purchases restored. Your plan was refreshed from verified StoreKit transactions."
        case .failed(let description):
            LocalizedStringKey("Restore failed: \(description)")
        }
    }

    var isRestoring: Bool {
        self == .restoring
    }

    var isError: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}
