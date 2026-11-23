import SwiftUI

struct ProgressView_: View {
    @EnvironmentObject var vm: ProgressViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if vm.isLoading {
                        ProgressView().padding(.top, 60)
                    } else {
                        // Overview cards
                        if let overview = vm.overview {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                StatCard(title: "Habits", value: "\(overview.totalHabits)", icon: "list.bullet.circle.fill", color: "#6366F1")
                                StatCard(title: "30-Day Rate", value: "\(overview.overallCompletionRate)%", icon: "chart.pie.fill", color: "#10B981")
                                StatCard(title: "Completions", value: "\(overview.totalCompletions30d)", icon: "checkmark.seal.fill", color: "#F59E0B")
                                StatCard(title: "Active Days", value: "\(overview.heatmap.count)", icon: "calendar.badge.checkmark", color: "#EC4899")
                            }
                            .padding(.horizontal)

                            // Heatmap
                            HeatmapView(data: overview.heatmap)
                                .padding(.horizontal)
                        }

                        // Streaks
                        if !vm.streaks.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Streaks")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(vm.streaks) { streak in
                                    StreakRow(streak: streak)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color(hex: color))
                Spacer()
            }
            Text(value)
                .font(.title).bold()
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 6)
    }
}

struct StreakRow: View {
    let streak: HabitStreak

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hex: streak.habitColor).opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: streak.habitIcon)
                    .foregroundColor(Color(hex: streak.habitColor))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(streak.habitName).font(.headline)
                Text("\(streak.completionRate)% completion rate")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundColor(.orange)
                    Text("\(streak.currentStreak)").bold()
                }
                Text("best: \(streak.longestStreak)").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.03), radius: 5)
    }
}

struct HeatmapView: View {
    let data: [String: HeatmapDay]

    var sortedDates: [String] {
        let cal = Calendar.current
        return (0..<30).compactMap { daysAgo -> String? in
            guard let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) else { return nil }
            return date.isoDateString
        }.reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("30-Day Activity")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                ForEach(sortedDates, id: \.self) { date in
                    let day = data[date]
                    RoundedRectangle(cornerRadius: 4)
                        .fill(day != nil ? Color(hex: "#6366F1").opacity(day!.rate * 0.8 + 0.15) : Color(.systemGray5))
                        .frame(height: 28)
                }
            }

            HStack {
                Text("Less").font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text("More").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 6)
    }
}
