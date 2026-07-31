import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var displayName: String = ""
    @Published private(set) var username: String = ""
    @Published private(set) var accountId: String = ""
    @Published var bannerMessage: String?
    @Published var isLoading = false

    var isAuthenticated: Bool { token != nil }

    init() {
        restoreSession()
    }

    func restoreSession() {
        guard let saved = KeychainStore.loadToken() else { return }
        token = saved
    }

    func login(username: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let response = try await APIClient.shared.login(username: username, password: password)
        try applySession(response)
    }

    func signup(payload: [String: String]) async throws {
        isLoading = true
        defer { isLoading = false }

        let response = try await APIClient.shared.signup(payload: payload)
        try applySession(response)
    }

    func logout() async {
        if let token {
            _ = try? await APIClient.shared.logout(token: token)
        }
        clearSession()
    }

    func applySession(_ response: LoginResponse) throws {
        try KeychainStore.saveToken(response.token)
        token = response.token
        displayName = response.name
        username = response.user
        accountId = response.accountId
    }

    func clearSession() {
        KeychainStore.deleteToken()
        token = nil
        displayName = ""
        username = ""
        accountId = ""
    }

    func showBanner(_ message: String) {
        bannerMessage = message
    }

    func clearBanner() {
        bannerMessage = nil
    }
}

@MainActor
final class HomeStore: ObservableObject {
    @Published var homeData: HomeData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            homeData = try await APIClient.shared.fetchHome(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
