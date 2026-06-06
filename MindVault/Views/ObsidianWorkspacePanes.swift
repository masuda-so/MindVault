import SwiftUI
import UIKit

struct ObsidianReadingPane: View {
    let note: Note?
    let notes: [Note]
    @Binding var selectedNoteID: UUID?
    var onCreateNote: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider()
                .overlay(ObsidianChromeStyle.border)
            breadcrumbBar
            Divider()
                .overlay(ObsidianChromeStyle.border.opacity(0.75))
            documentBody
            Divider()
                .overlay(ObsidianChromeStyle.border)
            statusBar
        }
        .foregroundStyle(ObsidianChromeStyle.primaryText)
        .background(ObsidianChromeStyle.editorBackground)
        .navigationTitle("")
        .toolbarBackground(ObsidianChromeStyle.rootBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var selectedNote: Note? {
        note ?? notes.first
    }

    private var tabStrip: some View {
        HStack(spacing: 1) {
            ForEach(notes.prefix(4)) { note in
                Button {
                    selectedNoteID = note.id
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: note.isPinned ? "pin" : "doc.text")
                            .font(.system(size: 10, weight: .semibold))
                        Text(note.title)
                            .lineLimit(1)
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(ObsidianChromeStyle.tertiaryText)
                    }
                    .font(.caption.weight(selectedNoteID == note.id ? .semibold : .regular))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .frame(maxWidth: 148)
                    .background(tabBackground(isSelected: selectedNoteID == note.id))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedNoteID == note.id ? ObsidianChromeStyle.primaryText : ObsidianChromeStyle.secondaryText)
            }

            Button(action: onCreateNote) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ObsidianChromeStyle.secondaryText)

            Spacer(minLength: 0)
        }
        .background(ObsidianChromeStyle.tabBarBackground)
    }

    private func tabBackground(isSelected: Bool) -> Color {
        isSelected ? ObsidianChromeStyle.editorBackground : ObsidianChromeStyle.tabBarBackground
    }

    private var breadcrumbBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "chevron.left")
            Image(systemName: "chevron.right")
                .foregroundStyle(ObsidianChromeStyle.tertiaryText)
            Text("MindVault")
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
            Text(selectedNote?.collectionName ?? "Vault")
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
            Text(selectedNote?.title ?? "No note")
                .foregroundStyle(ObsidianChromeStyle.primaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "book")
            Image(systemName: "ellipsis")
        }
        .font(.caption)
        .foregroundStyle(ObsidianChromeStyle.secondaryText)
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(ObsidianChromeStyle.editorBackground)
    }

    @ViewBuilder
    private var documentBody: some View {
        if let selectedNote {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(numberedLines(for: selectedNote)) { line in
                        ObsidianMarkdownLine(number: line.number, text: line.text)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            EmptyStateView(systemImage: "doc.text", title: String(localized: "No Notes"), message: String(localized: "Create a new note and it will appear here."))
        }
    }

    private func numberedLines(for note: Note) -> [NumberedMarkdownLine] {
        Array(note.markdown.split(separator: "\n", omittingEmptySubsequences: false).enumerated())
            .map { NumberedMarkdownLine(number: $0.offset + 1, text: String($0.element)) }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Text("\(notes.count) notes")
            Text("\(backlinkCount) backlinks")
            Text("\(selectedNote?.content?.wordCount ?? 0) words")
            Text("\(selectedNote?.content?.characterCount ?? 0) characters")
            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(ObsidianChromeStyle.secondaryText)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(ObsidianChromeStyle.tabBarBackground)
    }

    private var backlinkCount: Int {
        guard let selectedNote else { return 0 }
        return notes.filter { note in
            note.id != selectedNote.id && note.markdown.contains("[[\(selectedNote.title)]]")
        }.count
    }
}

private struct NumberedMarkdownLine: Identifiable {
    let number: Int
    let text: String

    var id: Int { number }
}

private struct ObsidianMarkdownLine: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(ObsidianChromeStyle.lineNumberText)
                .frame(width: 34, alignment: .trailing)

            lineContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.trailing, 18)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var lineContent: some View {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("## ") {
            Text(trimmed.replacingOccurrences(of: "## ", with: ""))
                .font(.title3.weight(.semibold))
                .foregroundStyle(ObsidianChromeStyle.headingText)
                .padding(.top, 7)
        } else if trimmed.hasPrefix("# ") {
            Text(trimmed.replacingOccurrences(of: "# ", with: ""))
                .font(.title2.weight(.semibold))
                .foregroundStyle(ObsidianChromeStyle.headingText)
                .padding(.top, 8)
        } else if trimmed.hasPrefix("- ") {
            Text("• \(trimmed.dropFirst(2))")
                .font(.body)
                .foregroundStyle(ObsidianChromeStyle.primaryText)
        } else if trimmed.contains("[[") {
            Text(trimmed)
                .font(.body)
                .foregroundStyle(ObsidianChromeStyle.linkText)
        } else if trimmed.hasPrefix("#") {
            Text(trimmed)
                .font(.callout.weight(.medium))
                .foregroundStyle(ObsidianChromeStyle.linkText.opacity(0.9))
        } else if trimmed.isEmpty {
            Text(" ")
                .font(.body)
        } else {
            Text(text)
                .font(.body)
                .foregroundStyle(ObsidianChromeStyle.primaryText)
        }
    }
}

struct ObsidianMiniCalendar: View {
    var date = Date.now

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(ObsidianChromeStyle.accent)
                Text(Self.monthFormatter.string(from: date))
                    .font(.headline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.left")
                Text("TODAY")
                    .font(.caption2.weight(.bold))
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(ObsidianChromeStyle.primaryText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(Self.weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ObsidianChromeStyle.secondaryText)
                }

                ForEach(daysForVisibleMonth(), id: \.self) { day in
                    Text(day.label)
                        .font(.system(size: 11, weight: day.isToday ? .bold : .medium))
                        .foregroundStyle(day.isCurrentMonth ? ObsidianChromeStyle.primaryText : ObsidianChromeStyle.tertiaryText)
                        .frame(width: 24, height: 22)
                        .background(day.isToday ? ObsidianChromeStyle.accent.opacity(0.28) : Color.clear, in: Circle())
                }
            }
        }
    }

    private func daysForVisibleMonth() -> [CalendarDay] {
        let components = calendar.dateComponents([.year, .month], from: date)
        let firstOfMonth = calendar.date(from: components) ?? date
        let range = calendar.range(of: .day, in: .month, for: firstOfMonth) ?? 1..<31
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: firstOfMonth) ?? firstOfMonth
        let previousRange = calendar.range(of: .day, in: .month, for: previousMonth) ?? 1..<31
        var days: [CalendarDay] = []

        if firstWeekday > 0 {
            let start = previousRange.count - firstWeekday + 1
            for day in start...previousRange.count {
                days.append(CalendarDay(label: "\(day)", isCurrentMonth: false, isToday: false))
            }
        }

        for day in range {
            let dayDate = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) ?? date
            days.append(CalendarDay(label: "\(day)", isCurrentMonth: true, isToday: calendar.isDateInToday(dayDate)))
        }

        while days.count % 7 != 0 {
            days.append(CalendarDay(label: "\(days.count % 7 + 1)", isCurrentMonth: false, isToday: false))
        }

        return days
    }

    private struct CalendarDay: Hashable {
        let label: String
        let isCurrentMonth: Bool
        let isToday: Bool
    }

    private static let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()
}

enum ObsidianChromeStyle {
    static let rootBackground = chromeColor(
        light: UIColor(red: 0.940, green: 0.940, blue: 0.930, alpha: 1),
        dark: UIColor(red: 0.105, green: 0.105, blue: 0.102, alpha: 1)
    )
    static let sidebarBackground = chromeColor(
        light: UIColor(red: 0.962, green: 0.962, blue: 0.952, alpha: 1),
        dark: UIColor(red: 0.118, green: 0.118, blue: 0.114, alpha: 1)
    )
    static let editorBackground = chromeColor(
        light: UIColor(red: 0.988, green: 0.988, blue: 0.978, alpha: 1),
        dark: UIColor(red: 0.128, green: 0.128, blue: 0.124, alpha: 1)
    )
    static let tabBarBackground = chromeColor(
        light: UIColor(red: 0.920, green: 0.922, blue: 0.912, alpha: 1),
        dark: UIColor(red: 0.100, green: 0.102, blue: 0.104, alpha: 1)
    )
    static let panelBackground = chromeColor(
        light: UIColor(red: 0.970, green: 0.970, blue: 0.960, alpha: 1),
        dark: UIColor(red: 0.138, green: 0.138, blue: 0.134, alpha: 1)
    )
    static let controlBackground = chromeColor(
        light: UIColor(red: 0.900, green: 0.905, blue: 0.900, alpha: 1),
        dark: UIColor(red: 0.170, green: 0.174, blue: 0.180, alpha: 1)
    )
    static let border = chromeColor(
        light: UIColor(red: 0.755, green: 0.760, blue: 0.748, alpha: 0.72),
        dark: UIColor(red: 0.235, green: 0.238, blue: 0.242, alpha: 0.92)
    )
    static let primaryText = chromeColor(
        light: UIColor(red: 0.105, green: 0.110, blue: 0.115, alpha: 1),
        dark: UIColor(red: 0.860, green: 0.880, blue: 0.900, alpha: 1)
    )
    static let secondaryText = chromeColor(
        light: UIColor(red: 0.390, green: 0.415, blue: 0.430, alpha: 1),
        dark: UIColor(red: 0.590, green: 0.620, blue: 0.650, alpha: 1)
    )
    static let tertiaryText = chromeColor(
        light: UIColor(red: 0.540, green: 0.560, blue: 0.570, alpha: 1),
        dark: UIColor(red: 0.420, green: 0.450, blue: 0.470, alpha: 1)
    )
    static let lineNumberText = chromeColor(
        light: UIColor(red: 0.445, green: 0.470, blue: 0.485, alpha: 1),
        dark: UIColor(red: 0.430, green: 0.480, blue: 0.540, alpha: 1)
    )
    static let headingText = chromeColor(
        light: UIColor(red: 0.020, green: 0.520, blue: 0.540, alpha: 1),
        dark: UIColor(red: 0.310, green: 0.760, blue: 0.780, alpha: 1)
    )
    static let linkText = chromeColor(
        light: UIColor(red: 0.020, green: 0.470, blue: 0.610, alpha: 1),
        dark: UIColor(red: 0.270, green: 0.700, blue: 0.900, alpha: 1)
    )
    static let accent = Color(red: 0.00, green: 0.72, blue: 0.68)
    static let amber = Color(red: 0.86, green: 0.66, blue: 0.05)
    static let violet = Color(red: 0.58, green: 0.32, blue: 0.62)
}

private func chromeColor(light: UIColor, dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}
