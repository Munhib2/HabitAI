import Foundation

// MARK: - User
struct User: Codable, Identifiable {
    let id: String
    var displayName: String
    var email: String?
    var subscriptionTier: SubscriptionTier
    var timezone: String
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, email, timezone
        case displayName = "display_name"
        case subscriptionTier = "subscription_tier"
        case createdAt = "created_at"
    }

    var isPremium: Bool { subscriptionTier == .premium }
}

enum SubscriptionTier: String, Codable {
    case free, premium
}

// MARK: - Habit
struct Habit: Codable, Identifiable {
    let id: String
    var name: String
    var description: String?
    var frequency: HabitFrequency
    var customDays: [Int]?
    var reminderTime: String?
    var color: String
    var icon: String
    var isArchived: Bool
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, description, frequency, color, icon
        case customDays = "custom_days"
        case reminderTime = "reminder_time"
        case isArchived = "is_archived"
        case createdAt = "created_at"
    }
}

enum HabitFrequency: String, Codable {
    case daily, weekly, custom
}

// MARK: - Checkin
struct Checkin: Codable, Identifiable {
    let id: String
    let habitId: String
    let userId: String
    var date: String
    var completed: Bool
    var note: String?
    var mood: Int?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, date, completed, note, mood
        case habitId = "habit_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

// MARK: - Today Habit (habit + today's checkin merged)
struct TodayHabit: Codable, Identifiable {
    let id: String
    var name: String
    var color: String
    var icon: String
    var completedToday: Bool
    var checkin: Checkin?
    var frequency: HabitFrequency

    enum CodingKeys: String, CodingKey {
        case id, name, color, icon, frequency, checkin
        case completedToday = "completed_today"
    }
}

// MARK: - AI Coaching Log
struct CoachingLog: Codable, Identifiable {
    let id: String
    let userId: String
    let type: String
    let content: String
    let generatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, content
        case userId = "user_id"
        case generatedAt = "generated_at"
    }
}

// MARK: - Stats
struct HabitStreak: Codable, Identifiable {
    var id: String { habitId }
    let habitId: String
    let habitName: String
    let habitColor: String
    let habitIcon: String
    let currentStreak: Int
    let longestStreak: Int
    let completionRate: Int
    let totalCompletions: Int

    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case habitName = "habit_name"
        case habitColor = "habit_color"
        case habitIcon = "habit_icon"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case completionRate = "completion_rate"
        case totalCompletions = "total_completions"
    }
}

struct StatsOverview: Codable {
    let totalHabits: Int
    let overallCompletionRate: Int
    let totalCompletions30d: Int
    let heatmap: [String: HeatmapDay]
    let habitsSummary: [HabitSummary]

    enum CodingKeys: String, CodingKey {
        case heatmap
        case totalHabits = "total_habits"
        case overallCompletionRate = "overall_completion_rate"
        case totalCompletions30d = "total_completions_30d"
        case habitsSummary = "habits_summary"
    }
}

struct HeatmapDay: Codable {
    let total: Int
    let completed: Int
    var rate: Double { total > 0 ? Double(completed) / Double(total) : 0 }
}

struct HabitSummary: Codable, Identifiable {
    let id: String
    let name: String
    let color: String
    let completions: Int
}

// MARK: - Voice Response
struct VoiceTranscribeResponse: Codable {
    let transcript: String
    let parsed: ParsedVoice
    let success: Bool
}

struct ParsedVoice: Codable {
    let completions: [VoiceCompletion]
    let note: String?
}

struct VoiceCompletion: Codable {
    let habitId: String
    let completed: Bool
    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case completed
    }
}

// MARK: - Auth
struct AuthResponse: Codable {
    let token: String
    let user: User
}
