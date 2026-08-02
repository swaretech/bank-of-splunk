import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    @FocusState private var focusedField: Field?

    #if DEBUG
    @State private var username = "testuser"
    @State private var password = "bankofsplunk"
    #else
    @State private var username = ""
    @State private var password = ""
    #endif
    @State private var errorMessage: String?

    private enum Field: Hashable {
        case username
        case password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Bank of Splunk")
                    .font(.largeTitle.bold())
                    .padding(.top, 40)

                VStack(alignment: .leading, spacing: 12) {
                    styledField {
                        TextField("Username", text: $username)
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .focused($focusedField, equals: .username)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }
                    .dxaTrackID(DXA.loginUsername)
                    .dxaSensitiveContent()

                    styledField {
                        SecureField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit(submit)
                    }
                    .dxaTrackID(DXA.loginPassword)
                    .dxaSensitiveContent()

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    Button(action: submit) {
                        if auth.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign in")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(auth.isLoading)
                    .dxaTrackID(DXA.loginSubmit)

                    NavigationLink {
                        SignupView()
                    } label: {
                        Text("Create an Account")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .dxaTrackID(DXA.signupNavigate)
                    .dxaInteraction(
                        trackId: DXA.signupNavigate,
                        component: DXA.authFormComponent,
                        flow: DXA.registrationFlow
                    )
                }
                .padding(.horizontal)

                #if DEBUG
                Text("API: \(AppConfig.apiBaseURL.absoluteString)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                #endif
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            BankRum.trackScreen(DXA.loginPage, flow: DXA.authenticationFlow)
        }
    }

    private func styledField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack {
            content()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private func submit() {
        focusedField = nil
        errorMessage = nil
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            BankRum.reportValidationFailed(
                trackId: DXA.loginSubmit,
                field: "username",
                component: DXA.authFormComponent,
                flow: DXA.authenticationFlow
            )
            errorMessage = "Username is required."
            focusedField = .username
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
            focusedField = .password
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
