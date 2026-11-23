import SwiftUI

struct CoachView: View {
    @EnvironmentObject var vm: CoachViewModel
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $selectedTab) {
                    Text("Summary").tag(0)
                    Text("Chat").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    WeeklySummaryTab()
                        .environmentObject(vm)
                } else {
                    ChatTab()
                        .environmentObject(vm)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI Coach")
            .task { await vm.loadWeeklySummary() }
        }
    }
}

struct WeeklySummaryTab: View {
    @EnvironmentObject var vm: CoachViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if vm.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Your AI coach is thinking...")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                } else if let log = vm.weeklyLog {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(Color(hex: "#6366F1"))
                            Text("Weekly Summary")
                                .font(.headline)
                            Spacer()
                            Text("This week")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(log.content)
                            .font(.body)
                            .lineSpacing(6)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 8)
                    .padding(.horizontal)
                } else if let error = vm.error {
                    PremiumPromptView(message: error)
                        .padding()
                }
            }
            .padding(.top)
        }
    }
}

struct ChatTab: View {
    @EnvironmentObject var vm: CoachViewModel
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.chatMessages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                        if vm.isChatLoading {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.chatMessages.count) { _ in
                    if let last = vm.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                TextField("Ask your coach...", text: $vm.chatInput, axis: .vertical)
                    .focused($inputFocused)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...4)

                Button {
                    Task { await vm.sendChatMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(vm.chatInput.isEmpty ? .secondary : Color(hex: "#6366F1"))
                }
                .disabled(vm.chatInput.isEmpty || vm.isChatLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
    }
}

struct ChatBubble: View {
    let message: CoachViewModel.ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }
            Text(message.text)
                .padding(14)
                .background(message.isUser ? Color(hex: "#6366F1") : Color(.systemGray5))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(18)
            if !message.isUser { Spacer(minLength: 60) }
        }
    }
}

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 7, height: 7)
                    .offset(y: animating ? -4 : 0)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animating)
            }
        }
        .padding(12)
        .background(Color(.systemGray5))
        .cornerRadius(16)
        .onAppear { animating = true }
    }
}

struct PremiumPromptView: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "#F59E0B"))
            Text("Premium Feature")
                .font(.title2).bold()
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            NavigationLink("Upgrade to Premium") {
                PaywallView()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#6366F1"))
        }
        .padding()
    }
}
