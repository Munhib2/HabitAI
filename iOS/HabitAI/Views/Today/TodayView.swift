import SwiftUI

struct TodayView: View {
    @EnvironmentObject var vm: TodayViewModel
    @State private var showAddHabit = false
    @State private var showVoice = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header card
                        VStack(alignment: .leading, spacing: 8) {
                            Text(vm.todayDateString)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Good \(greeting)!")
                                .font(.title).bold()
                            ProgressRing(progress: vm.completionRate)
                                .frame(width: 80, height: 80)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .offset(y: -40)
                                .padding(.bottom, -40)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 8)
                        .padding(.horizontal)

                        // Habit list
                        if vm.isLoading {
                            ProgressView().padding(.top, 40)
                        } else if vm.todayHabits.isEmpty {
                            EmptyHabitsView(showAdd: $showAddHabit)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(vm.todayHabits) { habit in
                                    HabitCard(habit: habit) {
                                        Task { await vm.toggleHabit(habit) }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                    .padding(.bottom, 100)
                }

                // Voice check-in FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showVoice = true
                        } label: {
                            Image(systemName: "mic.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color(hex: "#6366F1"))
                                .clipShape(Circle())
                                .shadow(color: Color(hex: "#6366F1").opacity(0.4), radius: 12, y: 4)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 90)
                    }
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddHabit = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hex: "#6366F1"))
                    }
                }
            }
            .sheet(isPresented: $showAddHabit) {
                AddHabitView()
            }
            .sheet(isPresented: $showVoice) {
                VoiceCheckinView()
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }
}

struct HabitCard: View {
    let habit: TodayHabit
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(habit.completedToday ? Color(hex: habit.color) : Color(hex: habit.color).opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: habit.icon)
                        .font(.title3)
                        .foregroundColor(habit.completedToday ? .white : Color(hex: habit.color))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(habit.completedToday ? "Completed" : "Not done yet")
                        .font(.caption)
                        .foregroundColor(habit.completedToday ? .green : .secondary)
                }

                Spacer()

                Image(systemName: habit.completedToday ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(habit.completedToday ? Color(hex: habit.color) : .secondary.opacity(0.4))
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 6)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "#6366F1").opacity(0.15), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color(hex: "#6366F1"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.caption).bold()
                .foregroundColor(Color(hex: "#6366F1"))
        }
    }
}

struct EmptyHabitsView: View {
    @Binding var showAdd: Bool
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#6366F1").opacity(0.5))
            Text("No habits yet")
                .font(.title3).bold()
            Text("Add your first habit to get started")
                .foregroundColor(.secondary)
            Button("Add Habit") { showAdd = true }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#6366F1"))
        }
        .padding(.top, 60)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}
