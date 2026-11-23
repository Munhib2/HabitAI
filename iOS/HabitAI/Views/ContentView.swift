import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        if auth.isAuthenticated {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

struct MainTabView: View {
    @StateObject private var todayVM = TodayViewModel()
    @StateObject private var progressVM = ProgressViewModel()
    @StateObject private var coachVM = CoachViewModel()
    @StateObject private var habitsVM = HabitsViewModel()

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "checkmark.circle.fill") }
                .environmentObject(todayVM)

            ProgressView_()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                .environmentObject(progressVM)

            CoachView()
                .tabItem { Label("Coach", systemImage: "brain.head.profile") }
                .environmentObject(coachVM)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .environmentObject(habitsVM)
        }
        .accentColor(Color(hex: "#6366F1"))
    }
}
