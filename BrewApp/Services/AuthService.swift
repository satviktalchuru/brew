import Foundation

@Observable
final class AuthService {

    private(set) var isAuthenticated: Bool
    private(set) var currentSession: SupabaseSession?
    private(set) var error: String?
    private(set) var resetPasswordMessage: String?
    // Non-nil while waiting for the user to type the 6-digit code we just
    // emailed them. The UI shows a code-entry screen for as long as this is set.
    private(set) var pendingConfirmationEmail: String?

    // Exposed so AppStore can be configured for sync once a session exists.
    let supabase = SupabaseService()

    private let defaults = UserDefaults.standard
    private static let refreshTokenAccount = "supabase.refreshToken"

    init() {
        self.isAuthenticated = defaults.bool(forKey: "brew.isAuthenticated")
    }

    // MARK: - Email Auth

    func signInWithEmail(email: String, password: String) async {
        await perform {
            try await self.supabase.signInWithEmail(email: email, password: password)
        }
    }

    func signUpWithEmail(email: String, password: String) async {
        error = nil
        do {
            let session = try await supabase.signUpWithEmail(email: email, password: password)
            await MainActor.run { self.apply(session) }
        } catch let e as SupabaseService.SupabaseError {
            await MainActor.run {
                switch e {
                case .confirmationRequired:
                    // Expected path when "Confirm email" is on: hand off to
                    // the code-entry screen instead of surfacing this as an error.
                    self.pendingConfirmationEmail = email
                case .notConfigured:
                    self.bypassForDemo()
                default:
                    self.error = e.errorDescription
                }
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Signup Confirmation Code
    // Typed 6-digit code instead of a tappable magic link — the code sits as
    // plain text in the email body, so mail apps/security scanners that
    // pre-fetch links (silently burning single-use tokens before the human
    // taps them) can't consume it. Also sidesteps needing any redirect_to
    // URL allow-listed in the Supabase dashboard.

    @discardableResult
    func confirmSignUp(code: String) async -> Bool {
        guard let email = pendingConfirmationEmail else { return false }
        error = nil
        do {
            let session = try await supabase.verifySignupOTP(email: email, token: code)
            await MainActor.run {
                self.pendingConfirmationEmail = nil
                self.apply(session)
            }
            return true
        } catch let e as SupabaseService.SupabaseError {
            await MainActor.run { self.error = e.errorDescription }
            return false
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
            return false
        }
    }

    func resendConfirmationCode() async {
        guard let email = pendingConfirmationEmail else { return }
        error = nil
        try? await supabase.resendSignupConfirmation(email: email)
    }

    // Lets the user back out to the email/password screen (e.g. to fix a typo'd address).
    func cancelPendingConfirmation() {
        pendingConfirmationEmail = nil
        error = nil
    }

    func sendPasswordReset(email: String) async {
        error = nil
        resetPasswordMessage = nil
        do {
            try await supabase.sendPasswordReset(email: email)
            await MainActor.run {
                self.resetPasswordMessage = "If that email has an account, a reset link is on its way."
            }
        } catch let e as SupabaseService.SupabaseError {
            await MainActor.run { self.error = e.errorDescription }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: - Email Confirmation Deep Link

    // Supabase's confirmation link verifies the email server-side, then
    // redirects the OS to redirect_to (brew://confirmed) with the new
    // session appended as a URL fragment: #access_token=...&refresh_token=...
    // Returns true if it found and applied a session (caller can then skip
    // any other deep-link handling for this URL).
    @discardableResult
    func handleEmailConfirmation(url: URL) async -> Bool {
        guard url.scheme == "brew", url.host == "confirmed" else { return false }

        let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment ?? ""
        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 { params[kv[0]] = kv[1].removingPercentEncoding ?? kv[1] }
        }

        guard let accessToken = params["access_token"], let refreshToken = params["refresh_token"] else {
            // Link was opened without tokens (e.g. already confirmed/expired) —
            // not an error state worth surfacing, just nothing to apply.
            return false
        }

        do {
            let userID = try await supabase.fetchUserID(accessToken: accessToken)
            let session = SupabaseSession(accessToken: accessToken, refreshToken: refreshToken, user: .init(id: userID))
            await MainActor.run { self.apply(session) }
            return true
        } catch {
            await MainActor.run { self.error = "Email confirmed, but sign-in failed — please sign in manually." }
            return false
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

    // MARK: - Account Deletion (Apple Guideline 5.1.1(v))

    // Permanently deletes the user's account and all associated data
    // (cascades server-side), then signs out locally. Returns false if the
    // request failed (e.g. offline) — the caller should tell the user to
    // retry rather than silently proceeding as if it worked.
    @discardableResult
    func deleteAccount() async -> Bool {
        guard let token = currentSession?.accessToken else { return false }
        do {
            try await supabase.deleteAccount(accessToken: token)
            await MainActor.run { self.signOut() }
            return true
        } catch {
            await MainActor.run { self.error = "Couldn't delete account: \(error.localizedDescription)" }
            return false
        }
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
