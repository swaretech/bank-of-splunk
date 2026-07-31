import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Bank of Splunk")
                    .font(.largeTitle.bold())
                    .padding(.top, 40)

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        .accessibilityIdentifier("login-username")

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        .accessibilityIdentifier("login-password")

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
                    .accessibilityIdentifier(DXA.loginSubmit)

                    NavigationLink {
                        SignupView()
                    } label: {
                        Text("Create an Account")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(DXA.signupNavigate)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            BankRum.trackScreen(DXA.loginPage, flow: DXA.authenticationFlow)
        }
    }

    private func submit() {
        errorMessage = nil
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            BankRum.reportValidationFailed(trackId: DXA.loginSubmit, field: "username")
            errorMessage = "Username is required."
            return
        }
        guard !password.isEmpty else {
            BankRum.reportValidationFailed(trackId: DXA.loginSubmit, field: "password")
            errorMessage = "Password is required."
            return
        }

        BankRum.reportSubmitStarted(trackId: DXA.loginSubmit)

        Task {
            do {
                try await auth.login(username: username, password: password)
            } catch {
                BankRum.reportLoginFailed()
                errorMessage = "Invalid username or password."
            }
        }
    }
}
