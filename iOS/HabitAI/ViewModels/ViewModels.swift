import SwiftUI

@MainActor
class TodayViewModel: ObservableObject {
    @Published var todayHabits: [TodayHabit] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var showVoiceCheckin = false

    var completionRate: Double {
        guard !todayHabits.isEmpty else { return 0 }
        return Double(todayHabits.filter { $0.completedToday }.count) / Double(todayHabits.count)
    }

    var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            todayHabits = try await APIClient.shared.getTodayHabits()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleHabit(_ habit: TodayHabit) async {
        let today = Date().isoDateString
        let newState = !habit.completedToday

        // Optimistic update
        if let index = todayHabits.firstIndex(where: { $0.id == habit.id }) {
            todayHabits[index].completedToday = newState
        }

        do {
            _ = try await APIClient.shared.logCheckin(habitId: habit.id, date: today, completed: newState)
        } catch {
            // Revert on failure
            if let index = todayHabits.firstIndex(where: { $0.id == habit.id }) {
                todayHabits[index].completedToday = !newState
            }
            self.error = error.localizedDescription
        }
    }
}

@MainActor
class HabitsViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            habits = try await APIClient.shared.getHabits()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createHabit(name: String, frequency: String, color: String, icon: String) async throws {
        let habit = try await APIClient.shared.createHabit(name, frequency: frequency, color: color, icon: icon)
        habits.append(habit)
    }

    func deleteHabit(_ habit: Habit) async {
        do {
            try await APIClient.shared.deleteHabit(habit.id)
            habits.removeAll { $0.id == habit.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

@MainActor
class ProgressViewModel: ObservableObject {
    @Published var streaks: [HabitStreak] = []
    @Published var overview: StatsOverview?
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let streaksTask = APIClient.shared.getStreaks()
            async let overviewTask = APIClient.shared.getStatsOverview()
            streaks = try await streaksTask
            overview = try await overviewTask
        } catch {
            self.error = error.localizedDescription
        }
    }
}

@MainActor
class CoachViewModel: ObservableObject {
    @Published var weeklyLog: CoachingLog?
    @Published var chatMessages: [ChatMessage] = []
    @Published var chatInput = ""
    @Published var isLoading = false
    @Published var isChatLoading = false
    @Published var error: String?

    struct ChatMessage: Identifiable {
        let id = UUID()
        let text: String
        let isUser: Bool
    }

    func loadWeeklySummary() async {
        isLoading = true
        defer { isLoading = false }
        do {
            weeklyLog = try await APIClient.shared.getWeeklyCoaching()
        } catch APIError.premiumRequired {
            error = "Upgrade to Premium to access AI coaching"
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendChatMessage() async {
        let message = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        chatInput = ""

        chatMessages.append(ChatMessage(text: message, isUser: true))
        isChatLoading = true
        defer { isChatLoading = false }

        let history = chatMessages.dropLast().map { ["role": $0.isUser ? "user" : "assistant", "content": $0.text] }

        do {
            let reply = try await APIClient.shared.chat(message: message, history: history)
            chatMessages.append(ChatMessage(text: reply, isUser: false))
        } catch APIError.premiumRequired {
            chatMessages.append(ChatMessage(text: "Upgrade to Premium to chat with your AI coach!", isUser: false))
        } catch {
            chatMessages.append(ChatMessage(text: "Sorry, I couldn't respond. Try again.", isUser: false))
        }
    }
}
