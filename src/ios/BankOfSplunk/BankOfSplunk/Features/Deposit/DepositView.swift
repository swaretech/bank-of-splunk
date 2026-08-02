import SwiftUI

struct DepositView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    let homeData: HomeData

    @State private var useNewAccount = false
    @State private var selectedContact: Contact?
    @State private var externalAccountNum = ""
    @State private var externalRoutingNum = ""
    @State private var externalLabel = ""
    @State private var amount = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    private var externalContacts: [Contact] {
        homeData.contacts.filter { $0.isExternal }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                M3Card(title: "From Account") {
                    VStack(spacing: 16) {
                        Picker("Source", selection: $useNewAccount) {
                            Text("Existing External Account").tag(false)
                            Text("New External Account").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .tint(AppColors.primary)

                        if useNewAccount {
                            M3TextField(
                                label: "Account Number",
                                text: $externalAccountNum,
                                keyboardType: .numberPad
                            )
                            .dxaSensitiveContent()

                            M3TextField(
                                label: "Routing Number",
                                text: $externalRoutingNum,
                                keyboardType: .numberPad
                            )
                            .dxaSensitiveContent()

                            M3TextField(label: "Label (optional)", text: $externalLabel)
                                .dxaSensitiveContent()
                        } else {
                            Picker("Contact", selection: $selectedContact) {
                                Text("Select account").tag(Optional<Contact>.none)
                                ForEach(externalContacts) { contact in
                                    Text(contact.displayLabel).tag(Optional(contact))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppColors.primary)
                        }
                    }
                }
                .dxaSensitiveFormSection()

                M3Card(title: "Amount") {
                    M3TextField(
                        label: "Amount (USD)",
                        text: $amount,
                        systemImage: "dollarsign.circle",
                        keyboardType: .decimalPad
                    )
                    .dxaSensitiveContent()
                }
                .dxaSensitiveFormSection()

                if let errorMessage {
                    M3ErrorText(message: errorMessage)
                        .m3ErrorTransition(isVisible: true)
                }

                VStack(spacing: 12) {
                    M3FilledButton(
                        title: "Deposit",
                        isLoading: isSubmitting,
                        isDisabled: isSubmitting,
                        action: submit
                    )
                    .dxaTrackID(DXA.depositSubmit)

                    M3TextButton(title: "Cancel") {
                        BankRum.reportEvent("ui.screen_closed", attributes: ["screen": DXA.depositPage])
                        dismiss()
                    }
                    .dxaTrackID(DXA.depositCancel)
                }
            }
            .padding()
        }
        .background(AppColors.surface)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneToolbar()
        .navigationTitle("Deposit Funds")
        .onAppear {
            selectedContact = externalContacts.first
            BankRum.trackScreen(DXA.depositPage, component: DXA.depositScreenComponent, flow: DXA.depositFlow)
            BankRum.reportScreenOpened(DXA.depositPage)
        }
    }

    private func submit() {
        errorMessage = nil

        guard let value = Decimal(string: amount), value > 0 else {
            BankRum.reportValidationFailed(
                trackId: DXA.depositSubmit,
                field: "amount",
                component: DXA.depositScreenComponent,
                flow: DXA.depositFlow
            )
            errorMessage = "Enter a valid amount greater than zero."
            return
        }

        var payload: [String: Any] = [
            "amount": NSDecimalNumber(decimal: value).stringValue,
            "uuid": UUID().uuidString,
            "use_new_account": useNewAccount,
        ]

        if useNewAccount {
            guard !externalAccountNum.isEmpty, !externalRoutingNum.isEmpty else {
                BankRum.reportValidationFailed(
                    trackId: DXA.depositSubmit,
                    field: "external_account",
                    component: DXA.depositScreenComponent,
                    flow: DXA.depositFlow
                )
                errorMessage = "External account and routing numbers are required."
                return
            }
            payload["external_account_num"] = externalAccountNum
            payload["external_routing_num"] = externalRoutingNum
            if !externalLabel.isEmpty {
                payload["external_label"] = externalLabel
            }
        } else {
            guard let contact = selectedContact else {
                BankRum.reportValidationFailed(
                    trackId: DXA.depositSubmit,
                    field: "account",
                    component: DXA.depositScreenComponent,
                    flow: DXA.depositFlow
                )
                errorMessage = "Select an external account."
                return
            }
            payload["account_num"] = contact.accountNum
            payload["routing_num"] = contact.routingNum
        }

        BankRum.reportSubmitStarted(
            trackId: DXA.depositSubmit,
            component: DXA.depositScreenComponent,
            flow: DXA.depositFlow
        )
        isSubmitting = true

        Task {
            defer { isSubmitting = false }
            guard let token = auth.token else { return }
            do {
                let message = try await APIClient.shared.deposit(token: token, payload: payload)
                auth.showBanner(message)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                BankRum.reportAPIError(operation: "deposit", error: error)
            }
        }
    }
}
