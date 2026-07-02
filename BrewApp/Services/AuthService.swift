import Foundation
import AuthenticationServices
import UIKit

@Observable
final class AuthService: NSObject {

    private(set) var isAuthenticated: Bool
    private(set) var currentSession: SupabaseSession?
    private(set) var error: String?

    // Exposed so AppStore can be configured for sync once a session exists.
    let supabase = SupabaseService()

    private let defaults = UserDefaults.standard
    private static let refreshTokenAccount = "supabase.refreshToken"

    // OAuth redirect back into the app (must be registered in Supabase Auth → URL Configuration).
    private static let oauthRedirect = "brew://login-callback"
    private var webAuthSession: ASWebAuthenticationSession?

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

    // MARK: - Sign In With Google (OAuth via web session)

    func signInWithGoogle() {
        let url = supabase.oauthAuthorizeURL(provider: "google", redirectTo: Self.oauthRedirect)
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "brew") { [weak self] callbackURL, error in
            guard let self else { return }
            if let error {
                // A user-initiated cancel isn't an error worth surfacing.
                if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                    Task { @MainActor in self.error = error.localizedDescription }
                }
                return
            }
            guard let callbackURL else { return }
            Task { await self.completeOAuth(callbackURL: callbackURL) }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        webAuthSession = session
        session.start()
    }

    private func completeOAuth(callbackURL: URL) async {
        let fragment = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.fragment ?? ""
        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 { params[kv[0]] = kv[1].removingPercentEncoding ?? kv[1] }
        }

        guard let access = params["access_token"], let refresh = params["refresh_token"] else {
            await MainActor.run {
                self.error = params["error_description"] ?? "Google sign-in was cancelled or failed."
            }
            return
        }

        do {
            let uid = try await supabase.fetchUserID(accessToken: access)
            let session = SupabaseSession(accessToken: access, refreshToken: refresh, user: .init(id: uid))
            await MainActor.run { self.apply(session) }
        } catch let e as SupabaseService.SupabaseError {
            await MainActor.run { self.error = e.errorDescription }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
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

    // Force a token refresh (used when a request comes back 401). Returns the
    // new session, or nil if the refresh token is gone/invalid.
    @discardableResult
    func refreshAccessToken() async -> SupabaseSession? {
        guard let refreshToken = currentSession?.refreshToken ?? KeychainStore.read(Self.refreshTokenAccount) else {
            return nil
        }
        do {
            let session = try await supabase.refreshSession(refreshToken: refreshToken)
            await MainActor.run { self.apply(session) }
            return session
        } catch {
            return nil
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

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
