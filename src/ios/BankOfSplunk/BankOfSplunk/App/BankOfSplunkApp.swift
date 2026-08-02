import SwiftUI

@main
struct BankOfSplunkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth: AuthStore

    init() {
        // Install before AuthStore in case AppDelegate didFinishLaunching has not run yet.
        SplunkRUMConfiguration.install()
        _auth = StateObject(wrappedValue: AuthStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .tint(AppColors.primary)
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
            .animation(AppMotion.standardSpring, value: auth.isAuthenticated)
        }
    }
}
