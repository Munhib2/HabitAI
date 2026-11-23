import SwiftUI

struct AddHabitView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var frequency = "daily"
    @State private var selectedColor = "#6366F1"
    @State private var selectedIcon = "star.fill"
    @State private var isLoading = false
    @State private var error: String?

    let colors = ["#6366F1", "#EC4899", "#F59E0B", "#10B981", "#3B82F6", "#EF4444", "#8B5CF6", "#06B6D4"]
    let icons = ["star.fill", "heart.fill", "bolt.fill", "flame.fill", "figure.run", "book.fill",
                 "drop.fill", "moon.fill", "sun.max.fill", "music.note", "fork.knife", "brain.head.profile"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit Name") {
                    TextField("e.g. Morning Run", text: $name)
                }

                Section("Frequency") {
                    Picker("Frequency", selection: $frequency) {
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .opacity(selectedColor == color ? 1 : 0)
                                )
                                .onTapGesture { selectedColor = color }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            ZStack {
                                Circle()
                                    .fill(selectedIcon == icon ? Color(hex: selectedColor) : Color(.systemGray5))
                                    .frame(width: 46, height: 46)
                                Image(systemName: icon)
                                    .foregroundColor(selectedIcon == icon ? .white : .secondary)
                            }
                            .onTapGesture { selectedIcon = icon }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let error = error {
                    Section { Text(error).foregroundColor(.red).font(.caption) }
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isLoading { ProgressView() }
                        else { Text("Save").bold() }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
    }

    func save() async {
        isLoading = true
        do {
            _ = try await APIClient.shared.createHabit(name, frequency: frequency, color: selectedColor, icon: selectedIcon)
            dismiss()
        } catch APIError.premiumRequired {
            error = "You've reached the free limit of 3 habits. Upgrade to Premium for unlimited habits."
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
