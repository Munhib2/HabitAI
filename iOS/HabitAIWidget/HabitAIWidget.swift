import WidgetKit
import SwiftUI

struct HabitEntry: TimelineEntry {
    let date: Date
    let habits: [WidgetHabit]
    let completionRate: Double
}

struct WidgetHabit: Codable {
    let name: String
    let icon: String
    let color: String
    let completed: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> HabitEntry {
        HabitEntry(date: Date(), habits: [
            WidgetHabit(name: "Morning Run", icon: "figure.run", color: "#6366F1", completed: true),
            WidgetHabit(name: "Read 30 min", icon: "book.fill", color: "#10B981", completed: false),
        ], completionRate: 0.5)
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void) {
        // Load from shared UserDefaults (App Group)
        let habits = loadHabitsFromUserDefaults()
        let entry = HabitEntry(date: Date(), habits: habits, completionRate: computeRate(habits))
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    func loadHabitsFromUserDefaults() -> [WidgetHabit] {
        guard let defaults = UserDefaults(suiteName: "group.com.yourname.habitai"),
              let data = defaults.data(forKey: "today_habits"),
              let habits = try? JSONDecoder().decode([WidgetHabit].self, from: data)
        else { return [] }
        return habits
    }

    func computeRate(_ habits: [WidgetHabit]) -> Double {
        guard !habits.isEmpty else { return 0 }
        return Double(habits.filter { $0.completed }.count) / Double(habits.count)
    }
}

struct HabitAIWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall: SmallWidget(entry: entry)
        case .systemMedium: MediumWidget(entry: entry)
        default: SmallWidget(entry: entry)
        }
    }
}

struct SmallWidget: View {
    let entry: HabitEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "#6366F1"))
                Text("Today")
                    .font(.caption).bold()
            }
            Spacer()
            Text("\(Int(entry.completionRate * 100))%")
                .font(.largeTitle).bold()
                .foregroundColor(Color(hex: "#6366F1"))
            Text("\(entry.habits.filter { $0.completed }.count)/\(entry.habits.count) done")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

struct MediumWidget: View {
    let entry: HabitEntry
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text("Today")
                    .font(.caption).bold()
                    .foregroundColor(.secondary)
                Text("\(Int(entry.completionRate * 100))%")
                    .font(.largeTitle).bold()
                    .foregroundColor(Color(hex: "#6366F1"))
                Text("complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.habits.prefix(3), id: \.name) { habit in
                    HStack(spacing: 8) {
                        Image(systemName: habit.completed ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(habit.completed ? Color(hex: habit.color) : .secondary)
                            .font(.caption)
                        Text(habit.name)
                            .font(.caption)
                            .foregroundColor(habit.completed ? .primary : .secondary)
                    }
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

struct HabitAIWidget: Widget {
    let kind = "HabitAIWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HabitAIWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("HabitAI")
        .description("Track your daily habits at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
