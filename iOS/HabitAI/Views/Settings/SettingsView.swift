import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var habitsVM: HabitsViewModel
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var notificationsEnabled = false

    var body: some View {
        NavigationStack {
            List {
                // Profile section
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color(hex: "#6366F1"), Color(hex: "#8B5CF6")],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 60, height: 60)
                            Text(String(auth.currentUser?.displayName.prefix(1) ?? "H"))
                                .font(.title).bold()
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading) {
                            Text(auth.currentUser?.displayName ?? "").font(.headline)
                            Text(auth.currentUser?.isPremium == true ? "Premium Member" : "Free Plan")
                                .font(.caption)
                                .foregroundColor(auth.currentUser?.isPremium == true ? Color(hex: "#F59E0B") : .secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Upgrade section (free users only)
                if auth.currentUser?.isPremium == false {
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Color(hex: "#F59E0B"))
                                Text("Upgrade to Premium")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("7-day free trial")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "#6366F1"))
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Habits management
                Section("My Habits") {
                    if habitsVM.isLoading {
                        ProgressView()
                    } else {
                        ForEach(habitsVM.habits) { habit in
                            HabitRow(habit: habit)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { i in
                                Task { await habitsVM.deleteHabit(habitsVM.habits[i]) }
                            }
                        }

                        NavigationLink("Add New Habit") {
                            AddHabitView()
                        }
                    }
                }

                // Notifications
                Section("Notifications") {
                    Toggle("Streak Reminders", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { enabled in
                            if enabled { requestNotificationPermission() }
                        }
                }

                // Account
                Section("Account") {
                    Button(role: .destructive) {
                        auth.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section {
                    Text("HabitAI v1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                NavigationStack { PaywallView() }
            }
            .task { await habitsVM.load() }
            .onAppear { checkNotificationStatus() }
        }
    }

    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                notificationsEnabled = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}

struct HabitRow: View {
    let habit: Habit
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: habit.color).opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: habit.icon).foregroundColor(Color(hex: habit.color))
            }
            Text(habit.name)
            Spacer()
            Text(habit.frequency.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
