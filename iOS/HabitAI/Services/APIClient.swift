import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case serverError(String)
    case unauthorized
    case premiumRequired
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data received"
        case .serverError(let msg): return msg
        case .unauthorized: return "Please sign in again"
        case .premiumRequired: return "Upgrade to Premium to use this feature"
        case .networkError(let err): return err.localizedDescription
        }
    }
}

class APIClient {
    static let shared = APIClient()
    #if targetEnvironment(simulator)
    private let baseURL = "http://localhost:3000/api"
    #else
    private let baseURL = "http://192.168.18.194:3000/api"
    #endif

    private var authToken: String? {
        get { UserDefaults.standard.string(forKey: "auth_token") }
        set { UserDefaults.standard.set(newValue, forKey: "auth_token") }
    }

    func setToken(_ token: String) { authToken = token }
    func clearToken() { authToken = nil }
    var isAuthenticated: Bool { authToken != nil }

    private func makeRequest(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw APIError.noData }

            switch httpResponse.statusCode {
            case 200...299: return data
            case 401: throw APIError.unauthorized
            case 403:
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["upgrade_required"] as? Bool == true {
                    throw APIError.premiumRequired
                }
                throw APIError.unauthorized
            default:
                let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Request failed"
                throw APIError.serverError(msg)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    // MARK: - Auth
    func signInAsDemo() async throws -> AuthResponse {
        let data = try await makeRequest("/auth/demo", method: "POST", body: ["demo_id": "demo-local-user"])
        let response = try decode(AuthResponse.self, from: data)
        setToken(response.token)
        return response
    }

    func signInWithApple(identityToken: String, fullName: PersonNameComponents?) async throws -> AuthResponse {
        var body: [String: Any] = ["identityToken": identityToken]
        if let name = fullName {
            body["fullName"] = [
                "givenName": name.givenName ?? "",
                "familyName": name.familyName ?? ""
            ]
        }
        let data = try await makeRequest("/auth/apple", method: "POST", body: body)
        let response = try decode(AuthResponse.self, from: data)
        setToken(response.token)
        return response
    }

    func getMe() async throws -> User {
        let data = try await makeRequest("/auth/me")
        return try decode(User.self, from: data)
    }

    func registerDeviceToken(_ token: String) async throws {
        _ = try await makeRequest("/auth/device-token", method: "POST", body: ["device_token": token, "platform": "ios"])
    }

    // MARK: - Habits
    func getHabits() async throws -> [Habit] {
        let data = try await makeRequest("/habits")
        return try decode([Habit].self, from: data)
    }

    func createHabit(_ name: String, frequency: String = "daily", color: String = "#6366F1", icon: String = "star.fill") async throws -> Habit {
        let data = try await makeRequest("/habits", method: "POST", body: [
            "name": name, "frequency": frequency, "color": color, "icon": icon
        ])
        return try decode(Habit.self, from: data)
    }

    func updateHabit(_ id: String, updates: [String: Any]) async throws -> Habit {
        let data = try await makeRequest("/habits/\(id)", method: "PATCH", body: updates)
        return try decode(Habit.self, from: data)
    }

    func deleteHabit(_ id: String) async throws {
        _ = try await makeRequest("/habits/\(id)", method: "DELETE")
    }

    // MARK: - Checkins
    func getTodayHabits() async throws -> [TodayHabit] {
        let data = try await makeRequest("/checkins/today")
        return try decode([TodayHabit].self, from: data)
    }

    func logCheckin(habitId: String, date: String, completed: Bool, note: String? = nil, mood: Int? = nil) async throws -> Checkin {
        var body: [String: Any] = ["habit_id": habitId, "date": date, "completed": completed]
        if let note = note { body["note"] = note }
        if let mood = mood { body["mood"] = mood }
        let data = try await makeRequest("/checkins", method: "POST", body: body)
        return try decode(Checkin.self, from: data)
    }

    func getCheckins(range: String = "week", habitId: String? = nil) async throws -> [Checkin] {
        var path = "/checkins?range=\(range)"
        if let hid = habitId { path += "&habit_id=\(hid)" }
        let data = try await makeRequest(path)
        return try decode([Checkin].self, from: data)
    }

    // MARK: - Stats
    func getStreaks() async throws -> [HabitStreak] {
        let data = try await makeRequest("/stats/streaks")
        return try decode([HabitStreak].self, from: data)
    }

    func getStatsOverview() async throws -> StatsOverview {
        let data = try await makeRequest("/stats/overview")
        return try decode(StatsOverview.self, from: data)
    }

    // MARK: - Coaching
    func getWeeklyCoaching() async throws -> CoachingLog {
        let data = try await makeRequest("/coaching/weekly")
        return try decode(CoachingLog.self, from: data)
    }

    func getDailyInsight() async throws -> String {
        let data = try await makeRequest("/coaching/insight")
        let json = try JSONDecoder().decode([String: String].self, from: data)
        return json["insight"] ?? ""
    }

    func chat(message: String, history: [[String: String]] = []) async throws -> String {
        let data = try await makeRequest("/coaching/chat", method: "POST", body: [
            "message": message,
            "conversation_history": history
        ])
        let json = try JSONDecoder().decode([String: String].self, from: data)
        return json["reply"] ?? ""
    }

    // MARK: - Voice (transcript already done on-device by Apple Speech)
    func transcribeVoice(transcript: String) async throws -> VoiceTranscribeResponse {
        let data = try await makeRequest("/voice/parse", method: "POST", body: ["transcript": transcript])
        return try decode(VoiceTranscribeResponse.self, from: data)
    }

    // MARK: - Subscriptions
    func verifySubscription(transactionId: String, productId: String) async throws {
        _ = try await makeRequest("/subscriptions/verify", method: "POST", body: [
            "transaction_id": transactionId,
            "product_id": productId
        ])
    }
}
