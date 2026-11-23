import SwiftUI
import AuthenticationServices

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    @Published var isAuthenticated = false

    init() {
        isAuthenticated = APIClient.shared.isAuthenticated
        if isAuthenticated {
            Task { await loadUser() }
        }
    }

    func loadUser() async {
        do {
            currentUser = try await APIClient.shared.getMe()
            isAuthenticated = true
        } catch APIError.unauthorized {
            signOut()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        defer { isLoading = false }

        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8)
            else {
                error = "Apple Sign In failed"
                return
            }
            do {
                let response = try await APIClient.shared.signInWithApple(
                    identityToken: token,
                    fullName: credential.fullName
                )
                currentUser = response.user
                isAuthenticated = true
            } catch {
                self.error = error.localizedDescription
            }
        case .failure(let err):
            error = err.localizedDescription
        }
    }

    func signInAsDemo() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.signInAsDemo()
            currentUser = response.user
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signOut() {
        APIClient.shared.clearToken()
        currentUser = nil
        isAuthenticated = false
    }
}
