import SwiftUI

struct PaymentView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    let homeData: HomeData

    @State private var useNewRecipient = false
    @State private var selectedContact: Contact?
    @State private var contactAccountNum = ""
    @State private var contactLabel = ""
    @State private var amount = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    private var internalContacts: [Contact] {
        homeData.contacts.filter { !$0.isExternal }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                M3Card(title: "Recipient") {
                    VStack(spacing: 16) {
                        Picker("Recipient", selection: $useNewRecipient) {
                            Text("Existing Recipient").tag(false)
                            Text("New Recipient").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .tint(AppColors.primary)

                        if useNewRecipient {
                            M3TextField(
                                label: "Account Number",
                                text: $contactAccountNum,
                                keyboardType: .numberPad
                            )
                            .dxaSensitiveContent()

                            M3TextField(label: "Label (optional)", text: $contactLabel)
                                .dxaSensitiveContent()
                        } else {
                            Picker("Contact", selection: $selectedContact) {
                                Text("Select recipient").tag(Optional<Contact>.none)
                                ForEach(internalContacts) { contact in
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
                    VStack(alignment: .leading, spacing: 12) {
                        M3TextField(
                            label: "Amount (USD)",
                            text: $amount,
                            systemImage: "dollarsign.circle",
                            keyboardType: .decimalPad
                        )
                        .dxaTrackID(DXA.paymentAmount)
                        .dxaSensitiveContent()

                        Text("Available: \(CurrencyFormatter.format(cents: homeData.balance))")
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.onSurfaceVariant)
                            .dxaSensitiveContent()
                    }
                }
                .dxaSensitiveFormSection()

                if let errorMessage {
                    M3ErrorText(message: errorMessage)
                        .m3ErrorTransition(isVisible: true)
                }

                VStack(spacing: 12) {
                    M3FilledButton(
                        title: "Send Payment",
                        isLoading: isSubmitting,
                        isDisabled: isSubmitting,
                        action: submit
                    )
                    .dxaTrackID(DXA.paymentSubmit)

                    M3TextButton(title: "Cancel") {
                        BankRum.reportEvent("ui.screen_closed", attributes: ["screen": DXA.paymentPage])
                        dismiss()
                    }
                    .dxaTrackID(DXA.paymentCancel)
                }
            }
            .padding()
        }
        .background(AppColors.surface)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneToolbar()
        .navigationTitle("Send Payment")
        .onAppear {
            selectedContact = internalContacts.first
            BankRum.trackScreen(DXA.paymentPage, component: DXA.paymentScreenComponent, flow: DXA.paymentFlow)
            BankRum.reportScreenOpened(DXA.paymentPage)
        }
    }

    private func submit() {
        errorMessage = nil

        guard let value = Decimal(string: amount), value > 0 else {
            BankRum.reportValidationFailed(
                trackId: DXA.paymentSubmit,
                field: "amount",
                component: DXA.paymentScreenComponent,
                flow: DXA.paymentFlow
            )
            errorMessage = "Enter a valid amount greater than zero."
            return
        }

        let cents = (value * 100 as NSDecimalNumber).intValue
        if cents > homeData.balance {
            BankRum.reportValidationFailed(
                trackId: DXA.paymentSubmit,
                field: "amount",
                component: DXA.paymentScreenComponent,
                flow: DXA.paymentFlow
            )
            errorMessage = "Amount exceeds available balance."
            return
        }

        var payload: [String: Any] = [
            "amount": NSDecimalNumber(decimal: value).stringValue,
            "uuid": UUID().uuidString,
            "use_new_recipient": useNewRecipient,
        ]

        if useNewRecipient {
            guard !contactAccountNum.isEmpty else {
                BankRum.reportValidationFailed(
                    trackId: DXA.paymentSubmit,
                    field: "contact_account_num",
                    component: DXA.paymentScreenComponent,
                    flow: DXA.paymentFlow
                )
                errorMessage = "Recipient account number is required."
                return
            }
            payload["contact_account_num"] = contactAccountNum
            if !contactLabel.isEmpty {
                payload["contact_label"] = contactLabel
            }
        } else {
            guard let contact = selectedContact else {
                BankRum.reportValidationFailed(
                    trackId: DXA.paymentSubmit,
                    field: "account_num",
                    component: DXA.paymentScreenComponent,
                    flow: DXA.paymentFlow
                )
                errorMessage = "Select a recipient."
                return
            }
            payload["account_num"] = contact.accountNum
        }

        isSubmitting = true

        Task {
            defer { isSubmitting = false }
            guard let token = auth.token else { return }
            do {
                try await BankRum.runWorkflow(
                    Workflow.payment,
                    trackId: DXA.paymentSubmit,
                    component: DXA.paymentScreenComponent,
                    flow: DXA.paymentFlow,
                    extraAttributes: ["recipient.mode": useNewRecipient ? "new" : "existing"]
                ) {
                    let message = try await APIClient.shared.payment(token: token, payload: payload)
                    auth.showBanner(message)
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
                BankRum.reportAPIError(operation: "payment", error: error)
            }
        }
    }
}
