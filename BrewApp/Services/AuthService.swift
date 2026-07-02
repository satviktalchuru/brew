import Foundation
import AuthenticationServices

@Observable
final class AuthService: NSObject {

    private(set) var isAuthenticated: Bool
    private(set) var currentSession: SupabaseSession?
    private(set) var error: String?

    // Exposed so AppStore can be configured for sync once a session exists.
    let supabase = SupabaseService()

    private let defaults = UserDefaults.standard
    private static let refreshTokenAccount = "supabase.refreshToken"

    override init() {
        self.isAuthenticated = defaults.bool(forKey: "brew.isAuthenticated")
        super.init()
    }

    // MARK: - Sign In With Apple

    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    // MARK: - Email Auth

    func signInWithEmail(email: String, password: String) async {
        await perform {
            try await self.supabase.signInWithEmail(email: email, password: password)
        }
    }

    func signUpWithEmail(email: String, password: String) async {
        await perform {
            try await self.supabase.signUpWithEmail(email: email, password: password)
        }
    }

    // MARK: - Session Restore & Refresh

    // Called on cold launch: if a refresh token is stored, exchange it for a
    // fresh session so returning users resume their real (synced) account.
    func restoreSession() async {
        guard currentSession == nil,
              let refreshToken = KeychainStore.read(Self.refreshTokenAccount)
        else { return }
        do {
            let session = try await supabase.refreshSession(refreshToken: refreshToken)
            await MainActor.run { self.apply(session) }
        } catch {
            // Refresh token expired or revoked — force a clean sign-in.
            await MainActor.run { self.signOut() }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        if let token = currentSession?.accessToken {
            Task { try? await supabase.signOut(accessToken: token) }
        }
        KeychainStore.delete(Self.refreshTokenAccount)
        currentSession = nil
        isAuthenticated = false
        defaults.set(false, forKey: "brew.isAuthenticated")
    }

    // MARK: - Dev helper — skip auth for simulator/demo builds

    func bypassForDemo() {
        // No session → AppStore stays in local mock (demo) mode.
        currentSession = nil
        isAuthenticated = true
        defaults.set(true, forKey: "brew.isAuthenticated")
    }

    // MARK: - Private

    private func apply(_ session: SupabaseSession) {
        self.currentSession = session
        self.isAuthenticated = true
        self.defaults.set(true, forKey: "brew.isAuthenticated")
        KeychainStore.save(session.refreshToken, for: Self.refreshTokenAccount)
    }

    private func perform(_ block: @escaping () async throws -> SupabaseSession) async {
        error = nil
        do {
            let session = try await block()
            await MainActor.run { self.apply(session) }
        } catch let e as SupabaseService.SupabaseError {
            await MainActor.run {
                if case .notConfigured = e {
                    // Supabase not wired up — fall back to local demo mode.
                    self.bypassForDemo()
                } else {
                    self.error = e.errorDescription
                }
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8)
        else { return }

        Task {
            await perform { try await self.supabase.signInWithApple(identityToken: token) }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in self.error = error.localizedDescription }
    }
}
