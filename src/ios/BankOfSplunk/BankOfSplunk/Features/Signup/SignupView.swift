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
        ScrollView {
            VStack(spacing: 20) {
                M3Card(title: "Account") {
                    VStack(spacing: 16) {
                        M3TextField(
                            label: "Username",
                            text: $username,
                            systemImage: "person.circle",
                            autocapitalization: .never
                        )
                        .dxaTrackID(DXA.signupUsername)
                        .dxaSensitiveContent()

                        M3SecureField(label: "Password", text: $password)
                            .dxaTrackID(DXA.signupPassword)
                            .dxaSensitiveContent()

                        M3SecureField(label: "Confirm Password", text: $passwordRepeat)
                            .dxaTrackID(DXA.signupPasswordRepeat)
                            .dxaSensitiveContent()
                    }
                }
                .dxaSensitiveFormSection()

                M3Card(title: "Personal") {
                    VStack(spacing: 16) {
                        M3TextField(label: "First Name", text: $firstname, systemImage: "person")
                            .dxaTrackID(DXA.signupFirstname)
                            .dxaSensitiveContent()

                        M3TextField(label: "Last Name", text: $lastname, systemImage: "person")
                            .dxaTrackID(DXA.signupLastname)
                            .dxaSensitiveContent()

                        M3TextField(
                            label: "Birthday (YYYY-MM-DD)",
                            text: $birthday,
                            systemImage: "calendar"
                        )
                        .dxaTrackID(DXA.signupBirthday)
                        .dxaSensitiveContent()
                    }
                }
                .dxaSensitiveFormSection()

                if let errorMessage {
                    M3ErrorText(message: errorMessage)
                        .m3ErrorTransition(isVisible: true)
                        .padding(.horizontal, 4)
                }

                M3FilledButton(title: "Create Account", action: submit)
                    .dxaTrackID(DXA.signupSubmit)
                    .padding(.top, 4)
            }
            .padding()
        }
        .background(AppColors.surface)
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
