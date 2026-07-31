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
        Form {
            Section("Recipient") {
                Picker("Recipient", selection: $useNewRecipient) {
                    Text("Existing Recipient").tag(false)
                    Text("New Recipient").tag(true)
                }
                .pickerStyle(.segmented)

                if useNewRecipient {
                    TextField("Account Number", text: $contactAccountNum)
                        .keyboardType(.numberPad)
                    TextField("Label (optional)", text: $contactLabel)
                } else {
                    Picker("Contact", selection: $selectedContact) {
                        Text("Select recipient").tag(Optional<Contact>.none)
                        ForEach(internalContacts) { contact in
                            Text(contact.displayLabel).tag(Optional(contact))
                        }
                    }
                }
            }

            Section("Amount") {
                TextField("Amount (USD)", text: $amount)
                    .keyboardType(.decimalPad)
                Text("Available: \(CurrencyFormatter.format(cents: homeData.balance))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Send Payment", action: submit)
                    .disabled(isSubmitting)
                    .accessibilityIdentifier(DXA.paymentSubmit)
                Button("Cancel", role: .cancel) {
                    BankRum.reportEvent("ui.screen_closed", attributes: ["screen": DXA.paymentPage])
                    dismiss()
                }
                .accessibilityIdentifier(DXA.paymentCancel)
            }
        }
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
            BankRum.reportValidationFailed(trackId: DXA.paymentSubmit, field: "amount")
            errorMessage = "Enter a valid amount greater than zero."
            return
        }

        let cents = (value * 100 as NSDecimalNumber).intValue
        if cents > homeData.balance {
            BankRum.reportValidationFailed(trackId: DXA.paymentSubmit, field: "amount")
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
                BankRum.reportValidationFailed(trackId: DXA.paymentSubmit, field: "contact_account_num")
                errorMessage = "Recipient account number is required."
                return
            }
            payload["contact_account_num"] = contactAccountNum
            if !contactLabel.isEmpty {
                payload["contact_label"] = contactLabel
            }
        } else {
            guard let contact = selectedContact else {
                BankRum.reportValidationFailed(trackId: DXA.paymentSubmit, field: "account_num")
                errorMessage = "Select a recipient."
                return
            }
            payload["account_num"] = contact.accountNum
        }

        BankRum.reportSubmitStarted(trackId: DXA.paymentSubmit)
        isSubmitting = true

        Task {
            defer { isSubmitting = false }
            guard let token = auth.token else { return }
            do {
                let message = try await APIClient.shared.payment(token: token, payload: payload)
                auth.showBanner(message)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
