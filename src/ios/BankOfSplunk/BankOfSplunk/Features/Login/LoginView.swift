import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore

    #if DEBUG
    @State private var username = "testuser"
    @State private var password = "bankofsplunk"
    #else
    @State private var username = ""
    @State private var password = ""
    #endif
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Bank of Splunk")
                        .font(AppTypography.displaySmall)
                        .foregroundStyle(AppColors.onSurface)
                    Text("Sign in to your account")
                        .font(AppTypography.bodyLarge)
                        .foregroundStyle(AppColors.onSurfaceVariant)
                }
                .padding(.top, 48)

                M3Card {
                    VStack(spacing: 16) {
                        M3TextField(
                            label: "Username",
                            text: $username,
                            systemImage: "person.circle",
                            textContentType: .username,
                            autocapitalization: .never,
                            submitLabel: .next
                        )
                        .dxaTrackID(DXA.loginUsername)
                        .dxaSensitiveContent()

                        M3SecureField(
                            label: "Password",
                            text: $password,
                            submitLabel: .go,
                            onSubmit: submit
                        )
                        .dxaTrackID(DXA.loginPassword)
                        .dxaSensitiveContent()

                        if let errorMessage {
                            M3ErrorText(message: errorMessage)
                                .m3ErrorTransition(isVisible: true)
                        }

                        M3FilledButton(
                            title: "Sign in",
                            isLoading: auth.isLoading,
                            isDisabled: auth.isLoading,
                            action: submit
                        )
                        .dxaTrackID(DXA.loginSubmit)

                        NavigationLink {
                            SignupView()
                        } label: {
                            Text("Create an Account")
                                .font(AppTypography.labelLarge)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(AppColors.primary)
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppShape.full)
                                        .stroke(AppColors.outline, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .dxaTrackID(DXA.signupNavigate)
                        .dxaInteraction(
                            trackId: DXA.signupNavigate,
                            component: DXA.authFormComponent,
                            flow: DXA.registrationFlow
                        )
                    }
                }
                .dxaSensitiveFormSection()
                .padding(.horizontal)

                #if DEBUG
                Text("API: \(AppConfig.apiBaseURL.absoluteString)")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .dxaSensitiveContent()
                #endif
            }
            .padding(.bottom, 32)
        }
        .background(AppColors.surface)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            BankRum.trackScreen(DXA.loginPage, flow: DXA.authenticationFlow)
        }
    }

    private func submit() {
        errorMessage = nil
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            BankRum.reportValidationFailed(
                trackId: DXA.loginSubmit,
                field: "username",
                component: DXA.authFormComponent,
                flow: DXA.authenticationFlow
            )
            errorMessage = "Username is required."
            return
        }
        guard !password.isEmpty else {
            BankRum.reportValidationFailed(
                trackId: DXA.loginSubmit,
                field: "password",
                component: DXA.authFormComponent,
                flow: DXA.authenticationFlow
            )
            errorMessage = "Password is required."
            return
        }

        BankRum.reportSubmitStarted(
            trackId: DXA.loginSubmit,
            component: DXA.authFormComponent,
            flow: DXA.authenticationFlow
        )

        Task {
            do {
                try await auth.login(username: username, password: password)
            } catch let error as APIClientError {
                BankRum.reportLoginFailed()
                switch error {
                case .unauthorized:
                    errorMessage = "Invalid username or password."
                default:
                    errorMessage = error.localizedDescription
                    BankRum.reportAPIError(operation: "login", error: error)
                }
            } catch {
                BankRum.reportLoginFailed()
                errorMessage = error.localizedDescription
                BankRum.reportAPIError(operation: "login", error: error)
            }
        }
    }
}
