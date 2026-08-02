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
                    .dxaTrackID(DXA.signupUsername)
                    .dxaSensitiveContent()
                SecureField("Password", text: $password)
                    .dxaTrackID(DXA.signupPassword)
                    .dxaSensitiveContent()
                SecureField("Confirm Password", text: $passwordRepeat)
                    .dxaTrackID(DXA.signupPasswordRepeat)
                    .dxaSensitiveContent()
            }

            Section("Personal") {
                TextField("First Name", text: $firstname)
                    .dxaTrackID(DXA.signupFirstname)
                    .dxaSensitiveContent()
                TextField("Last Name", text: $lastname)
                    .dxaTrackID(DXA.signupLastname)
                    .dxaSensitiveContent()
                TextField("Birthday (YYYY-MM-DD)", text: $birthday)
                    .dxaTrackID(DXA.signupBirthday)
                    .dxaSensitiveContent()
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Create Account", action: submit)
                    .dxaTrackID(DXA.signupSubmit)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneToolbar()
        .navigationTitle("Sign Up")
        .onAppear {
            BankRum.trackScreen(
                DXA.signupPage,
                component: DXA.authFormComponent,
                flow: DXA.registrationFlow
            )
        }
    }

    private func submit() {
        errorMessage = nil

        guard !username.isEmpty else {
            BankRum.reportValidationFailed(
                trackId: DXA.signupSubmit,
                field: "username",
                component: DXA.authFormComponent,
                flow: DXA.registrationFlow
            )
            errorMessage = "Username is required."
            return
        }
        guard password == passwordRepeat else {
            BankRum.reportValidationFailed(
                trackId: DXA.signupSubmit,
                field: "password-repeat",
                component: DXA.authFormComponent,
                flow: DXA.registrationFlow
            )
            errorMessage = "Passwords do not match."
            return
        }

        BankRum.reportSubmitStarted(
            trackId: DXA.signupSubmit,
            component: DXA.authFormComponent,
            flow: DXA.registrationFlow
        )

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
                BankRum.reportAPIError(operation: "signup", error: error)
            }
        }
    }
}
