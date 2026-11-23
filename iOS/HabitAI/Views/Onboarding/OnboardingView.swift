import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var page = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#6366F1"), Color(hex: "#8B5CF6")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack {
                TabView(selection: $page) {
                    OnboardingPage1().tag(0)
                    OnboardingPage2().tag(1)
                    OnboardingPage3(auth: auth).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.white : Color.white.opacity(0.4))
                            .frame(width: i == page ? 10 : 7, height: i == page ? 10 : 7)
                            .animation(.spring(), value: page)
                    }
                }
                .padding(.bottom, 20)

                if page < 2 {
                    Button {
                        withAnimation { page += 1 }
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(Color(hex: "#6366F1"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct OnboardingPage1: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(.white)
            Text("Your AI Habit Coach")
                .font(.largeTitle).bold()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Build lasting habits with personalized AI coaching that understands you — not just checkboxes.")
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

struct OnboardingPage2: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "mic.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
            Text("Voice Check-ins")
                .font(.largeTitle).bold()
                .foregroundColor(.white)
            Text("Just talk. Say \"I ran 30 minutes and skipped meditation\" and we'll log it automatically.")
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

struct OnboardingPage3: View {
    @ObservedObject var auth: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 80))
                .foregroundColor(.white)
            Text("Track Your Growth")
                .font(.largeTitle).bold()
                .foregroundColor(.white)
            Text("Weekly AI summaries, streak tracking, and insights that actually help you improve.")
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()

            if auth.isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task { await auth.handleAppleSignIn(result: result) }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .cornerRadius(14)
                .padding(.horizontal, 32)

                Button {
                    Task { await auth.signInAsDemo() }
                } label: {
                    Text("Or Explore in Demo Mode")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(14)
                        .padding(.horizontal, 32)
                }
                .buttonStyle(.plain)
            }

            if let error = auth.error {
                Text(error)
                    .foregroundColor(.yellow)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer().frame(height: 30)
        }
    }
}
