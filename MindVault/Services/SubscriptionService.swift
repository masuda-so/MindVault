import Foundation
import Observation
import StoreKit

@Observable
@MainActor
final class SubscriptionService {
    static let proMonthlyProductID = "mindvault.pro.monthly"
    static let teamMonthlyProductID = "mindvault.team.monthly"
    static let subscriptionGroupID = "mindvault.ai.subscription"
    static let privacyPolicyURL = URL(string: "https://masuda-so.github.io/MindVault/privacy/")!
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var currentPlan: SubscriptionPlan = .free
    var aiCreditBalance: Int = 0
    var monthlyAIUsage: Int = 0

    var entitlement: SubscriptionEntitlement {
        SubscriptionEntitlement(
            plan: currentPlan,
            monthlyAIUsage: monthlyAIUsage,
            aiCreditBalance: aiCreditBalance,
            storageLimitGB: currentPlan == .free ? 5 : currentPlan == .pro ? 50 : 100
        )
    }

    func canRunAIOrganization(entitlement: SubscriptionEntitlement?) -> Bool {
        guard let entitlement else {
            return monthlyAIUsage < currentPlan.monthlyAILimit + aiCreditBalance
        }
        return entitlement.remainingAIOrganizeCount > 0
    }

    func refreshVerifiedEntitlement(_ entitlement: SubscriptionEntitlement?) async {
        let verifiedPlan = await verifiedPlanFromCurrentEntitlements()
        currentPlan = verifiedPlan
        guard let entitlement else { return }
        entitlement.plan = verifiedPlan
        entitlement.storageLimitGB = storageLimitGB(for: verifiedPlan)
        entitlement.updatedAt = .now
    }

    func restorePurchases(_ entitlement: SubscriptionEntitlement?) async throws {
        try await AppStore.sync()
        await refreshVerifiedEntitlement(entitlement)
    }

#if DEBUG
    func applyLocalPlanOverride(_ plan: SubscriptionPlan) {
        currentPlan = plan
    }
#endif

    private func storageLimitGB(for plan: SubscriptionPlan) -> Int {
        switch plan {
        case .free: 5
        case .pro: 50
        case .team: 100
        }
    }

    private func verifiedPlanFromCurrentEntitlements() async -> SubscriptionPlan {
        var bestPlan = SubscriptionPlan.free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expirationDate = transaction.expirationDate, expirationDate < .now {
                continue
            }

            switch transaction.productID {
            case Self.teamMonthlyProductID:
                return .team
            case Self.proMonthlyProductID:
                bestPlan = .pro
            default:
                continue
            }
        }
        return bestPlan
    }
}
