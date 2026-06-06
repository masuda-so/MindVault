import SwiftUI

struct NoteListView: View {
    let notes: [Note]
    let entitlement: SubscriptionEntitlement?
    @Binding var selectedNoteID: UUID?
    @Binding var mode: WorkspaceMode
    @Binding var searchText: String
    @Binding var selectedCollection: String?
    @Binding var selectedTag: String?
    @Binding var dateFilter: NoteDateFilter
    var onOpenNote: (() -> Void)? = nil
    var onOpenDailyNote: ((Date) -> Void)? = nil

    var filteredNotes: [Note] {
        notes
            .filter { note in
                guard !note.isArchived else { return false }
                if let selectedCollection, note.collectionName != selectedCollection { return false }
                if let selectedTag, !note.tags.contains(selectedTag) { return false }
                if !dateFilter.contains(note.updatedAt) { return false }
                guard !searchText.isEmpty else { return true }
                let haystack = "\(note.title) \(note.tags.joined(separator: " ")) \(note.markdown)".localizedLowercase
                return haystack.contains(searchText.localizedLowercase)
            }
            .sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned }
                return $0.updatedAt > $1.updatedAt
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            List(selection: $selectedNoteID) {
                ForEach(filteredNotes) { note in
                    NoteRow(note: note, isSelected: selectedNoteID == note.id)
                        .tag(note.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedNoteID = note.id
                            if let onOpenNote {
                                onOpenNote()
                            } else {
                                mode = .editor
                            }
                        }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Notes")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search notes", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(VaultSurface.controlBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterPill(title: selectedCollection ?? String(localized: "All"), icon: "folder")
                        if let selectedTag {
                            FilterPill(title: "#\(selectedTag)", icon: "tag")
                        }
                        Menu {
                            ForEach(NoteDateFilter.allCases) { filter in
                                Button(filter.title) {
                                    dateFilter = filter
                                }
                            }
                        } label: {
                            FilterPill(title: dateFilter.title, icon: "calendar")
                        }
                    }
                }
                Spacer()
                Text("\(filteredNotes.count) notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let onOpenDailyNote {
                DailyCalendarStrip(
                    notes: notes,
                    selectedNoteID: selectedNoteID,
                    onSelectDate: onOpenDailyNote
                )
            }

            AIUsageMeter(entitlement: entitlement)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NoteRow: View {
    let note: Note
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(note.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(note.updatedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(note.excerpt)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(note.tags.prefix(3), id: \.self) { tag in
                        TagChip(tag: tag)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(isSelected ? Color.mint.opacity(0.16) : Color.clear)
    }
}

private struct FilterPill: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.10), in: Capsule())
    }
}

private struct DailyCalendarStrip: View {
    let notes: [Note]
    let selectedNoteID: UUID?
    let onSelectDate: (Date) -> Void

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = .autoupdatingCurrent
        return calendar
    }

    private var weekDates: [Date] {
        let today = Date.now
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Label("Daily", systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(dailyNotes.count) notes")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(weekDates, id: \.self) { date in
                    dayButton(for: date)
                }
            }
        }
        .padding(10)
        .background(VaultSurface.controlBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var dailyNotes: [Note] {
        notes.filter(\.isDailyNote)
    }

    private func dayButton(for date: Date) -> some View {
        let dailyNote = dailyNote(for: date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = dailyNote?.id == selectedNoteID

        return Button {
            onSelectDate(date)
        } label: {
            VStack(spacing: 3) {
                Text(Self.weekdayFormatter.string(from: date))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.82) : Color.secondary)

                Text(Self.dayFormatter.string(from: date))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)

                Circle()
                    .fill(dailyNote == nil ? Color.clear : (isSelected ? Color.white : Color.mint))
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(dayBackground(isSelected: isSelected, isToday: isToday), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(dayBorder(isSelected: isSelected, isToday: isToday), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Daily \(Self.accessibilityDateFormatter.string(from: date))")
    }

    private func dailyNote(for date: Date) -> Note? {
        let normalizedDate = calendar.startOfDay(for: date)
        return dailyNotes.first { note in
            note.dailyDate.map { calendar.startOfDay(for: $0) == normalizedDate } == true
                || calendar.isDate(note.createdAt, inSameDayAs: date)
                || calendar.isDate(note.updatedAt, inSameDayAs: date)
                || note.title.contains(Self.titleDateFormatter.string(from: date))
        }
    }

    private func dayBackground(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return .mint }
        if isToday { return Color.mint.opacity(0.16) }
        return Color.secondary.opacity(0.06)
    }

    private func dayBorder(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return Color.mint.opacity(0.70) }
        if isToday { return Color.mint.opacity(0.42) }
        return Color.secondary.opacity(0.08)
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "E"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let titleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    private static let accessibilityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct AIUsageMeter: View {
    let entitlement: SubscriptionEntitlement?

    var body: some View {
        let plan = entitlement?.plan ?? .free
        let usage = entitlement?.monthlyAIUsage ?? 0
        let limit = plan.monthlyAILimit
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("AI Usage This Month", systemImage: "sparkles")
                Spacer()
                Text(plan.displayName)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            ProgressView(value: Double(min(usage, limit)), total: Double(limit))
                .tint(.mint)

            Text("\(usage) / \(limit) uses")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(VaultSurface.controlBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
