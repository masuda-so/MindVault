import SwiftUI
import UIKit

enum WorkspaceMode: String, CaseIterable, Identifiable {
    case graph
    case editor
    case search
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .graph: String(localized: "Graph")
        case .editor: String(localized: "Notes")
        case .search: String(localized: "AI Search")
        case .settings: String(localized: "Settings")
        }
    }

    var systemImage: String {
        switch self {
        case .graph: "point.3.connected.trianglepath.dotted"
        case .editor: "square.and.pencil"
        case .search: "sparkle.magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

enum NoteDateFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case last7Days
    case last30Days

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "All dates")
        case .today: String(localized: "Today")
        case .last7Days: String(localized: "Last 7 days")
        case .last30Days: String(localized: "Last 30 days")
        }
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            true
        case .today:
            calendar.isDateInToday(date)
        case .last7Days:
            date >= calendar.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        case .last30Days:
            date >= calendar.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        }
    }
}

struct VaultPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(VaultSurface.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(VaultSurface.panelBorder, lineWidth: 1)
            )
    }
}

enum VaultSurface {
    static let panelBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let panelBorder = Color(uiColor: .separator).opacity(0.36)
    static let controlBackground = Color(uiColor: .tertiarySystemGroupedBackground)
}

enum VaultAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct TagChip: View {
    let tag: String
    var isSelected = false

    var body: some View {
        Text("#\(tag)")
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? Color.mint.opacity(0.22) : Color.secondary.opacity(0.10), in: Capsule())
            .foregroundStyle(isSelected ? .mint : .secondary)
    }
}

struct PlanBadge: View {
    let plan: SubscriptionPlan

    var body: some View {
        Text(plan.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(plan == .free ? Color.secondary.opacity(0.12) : Color.mint.opacity(0.20), in: Capsule())
            .foregroundStyle(plan == .free ? Color.secondary : Color.mint)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding()
    }
}

extension Date {
    var compactDateTime: String {
        formatted(date: .abbreviated, time: .shortened)
    }
}
