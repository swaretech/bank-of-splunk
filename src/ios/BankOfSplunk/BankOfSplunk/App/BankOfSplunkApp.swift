import SwiftUI

@main
struct BankOfSplunkApp: App {
    @StateObject private var auth = AuthStore()

    init() {
        SplunkRUMConfiguration.install()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        NavigationStack {
            Group {
                if auth.isAuthenticated {
                    HomeView()
                } else {
                    LoginView()
                }
            }
        }
    }
}
