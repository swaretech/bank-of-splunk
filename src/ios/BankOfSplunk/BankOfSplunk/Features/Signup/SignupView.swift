import SwiftUI

struct SignupView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var passwordRepeat = ""
    @State private var firstname = "Demo"
    @State private var lastname = "User"
    @State private var birthday = "1990-01-01"
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Account") {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                SecureField("Confirm Password", text: $passwordRepeat)
            }

            Section("Personal") {
                TextField("First Name", text: $firstname)
                TextField("Last Name", text: $lastname)
                TextField("Birthday (YYYY-MM-DD)", text: $birthday)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Create Account", action: submit)
                    .accessibilityIdentifier(DXA.signupSubmit)
            }
        }
        .navigationTitle("Sign Up")
        .onAppear {
            BankRum.trackScreen(DXA.signupPage, flow: DXA.registrationFlow)
        }
    }

    private func submit() {
        errorMessage = nil

        guard !username.isEmpty else {
            BankRum.reportValidationFailed(trackId: DXA.signupSubmit, field: "username")
            errorMessage = "Username is required."
            return
        }
        guard password == passwordRepeat else {
            BankRum.reportValidationFailed(trackId: DXA.signupSubmit, field: "password-repeat")
            errorMessage = "Passwords do not match."
            return
        }

        BankRum.reportSubmitStarted(trackId: DXA.signupSubmit)

        let payload: [String: String] = [
            "username": username,
            "password": password,
            "password_repeat": passwordRepeat,
            "firstname": firstname,
            "lastname": lastname,
            "birthday": birthday,
        ]

        Task {
            do {
                try await auth.signup(payload: payload)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
