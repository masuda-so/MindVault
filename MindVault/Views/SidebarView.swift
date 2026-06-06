import SwiftUI
import SwiftData

struct SidebarView: View {
    let notes: [Note]
    let collections: [NoteCollection]
    let tags: [Tag]
    let entitlement: SubscriptionEntitlement?
    @Binding var mode: WorkspaceMode
    @Binding var selectedCollection: String?
    @Binding var selectedTag: String?

    var body: some View {
        HStack(spacing: 0) {
            sidebarIconRail
            Divider()
                .overlay(ObsidianChromeStyle.border)
            sidebarList
        }
        .background(ObsidianChromeStyle.sidebarBackground)
        .foregroundStyle(ObsidianChromeStyle.primaryText)
        .navigationTitle("MindVault")
        .toolbarBackground(ObsidianChromeStyle.sidebarBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(ObsidianChromeStyle.accent)
    }

    private var sidebarList: some View {
        List {
            Section {
                Label("Personal Vault", systemImage: "folder")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(ObsidianChromeStyle.primaryText)
            }

            Section("Workspace") {
                ForEach(WorkspaceMode.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .font(.subheadline)
                        .foregroundStyle(mode == item ? ObsidianChromeStyle.accent : ObsidianChromeStyle.primaryText)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            mode = item
                        }
                        .listRowBackground(mode == item ? ObsidianChromeStyle.controlBackground : Color.clear)
                }
            }

            Section("Assets") {
                Button {
                    selectedCollection = nil
                    selectedTag = nil
                    mode = .editor
                } label: {
                    Label("All Notes", systemImage: "tray.full")
                }

                ForEach(collections.sorted { $0.name < $1.name }) { collection in
                    Button {
                        selectedCollection = collection.name
                        selectedTag = nil
                        mode = .editor
                    } label: {
                        Label(collection.name, systemImage: collection.iconName)
                    }
                }
            }

            Section("Tags") {
                ForEach(tags.sorted { $0.usageCount > $1.usageCount }.prefix(8)) { tag in
                    Button {
                        selectedTag = tag.name
                        selectedCollection = nil
                        mode = .editor
                    } label: {
                        HStack {
                            Label(tag.name, systemImage: "number")
                            Spacer()
                            Text("\(notes.filter { $0.tags.contains(tag.name) }.count)")
                                .foregroundStyle(ObsidianChromeStyle.secondaryText)
                        }
                    }
                }
            }

            Section("Plan") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entitlement?.plan.displayName ?? "Free")
                            .font(.subheadline.weight(.semibold))
                        Text("AI organization \(entitlement?.monthlyAIUsage ?? 0)/\(entitlement?.plan.monthlyAILimit ?? SubscriptionPlan.free.monthlyAILimit)")
                            .font(.caption)
                            .foregroundStyle(ObsidianChromeStyle.secondaryText)
                    }
                    Spacer()
                    PlanBadge(plan: entitlement?.plan ?? .free)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(ObsidianChromeStyle.sidebarBackground)
    }

    private var sidebarIconRail: some View {
        VStack(spacing: 16) {
            railIcon("sidebar.left", selected: false)
            railIcon("folder", selected: true)
            railIcon("magnifyingglass", selected: false)
            railIcon("bookmark", selected: false)

            Divider()
                .overlay(ObsidianChromeStyle.border)
                .padding(.vertical, 2)

            railIcon("point.3.connected.trianglepath.dotted", selected: mode == .graph)
            railIcon("terminal", selected: false)
            railIcon("doc.on.doc", selected: false)
            railIcon("square.grid.2x2", selected: false)
            railIcon("calendar", selected: false)

            Spacer(minLength: 10)

            railIcon("questionmark.circle", selected: false)
            railIcon("gearshape", selected: mode == .settings)
        }
        .padding(.vertical, 12)
        .frame(width: 38)
        .background(ObsidianChromeStyle.tabBarBackground)
    }

    private func railIcon(_ systemImage: String, selected: Bool) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(selected ? ObsidianChromeStyle.accent : ObsidianChromeStyle.secondaryText)
            .frame(width: 28, height: 28)
            .background(selected ? ObsidianChromeStyle.controlBackground : Color.clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
