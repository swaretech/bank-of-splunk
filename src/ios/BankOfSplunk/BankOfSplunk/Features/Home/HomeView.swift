import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var homeStore = HomeStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let banner = auth.bannerMessage {
                    Text(banner)
                        .font(.footnote)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(8)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                auth.clearBanner()
                            }
                        }
                }

                if homeStore.isLoading && homeStore.homeData == nil {
                    ProgressView("Loading account…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let data = homeStore.homeData {
                    overviewSection(data)
                    actionCards(data)
                    transactionSection(data)
                } else if let error = homeStore.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle(dataTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign out") {
                    Task { await auth.logout() }
                }
                .accessibilityIdentifier(DXA.logoutSubmit)
            }
        }
        .refreshable {
            await reload()
        }
        .task {
            await reload()
        }
        .onAppear {
            BankRum.trackScreen(DXA.homePage)
        }
    }

    private var dataTitle: String {
        homeStore.homeData?.bankName ?? "Bank of Splunk"
    }

    @ViewBuilder
    private func overviewSection(_ data: HomeData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Checking Account")
                .font(.headline)
            Text(data.accountId)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(CurrencyFormatter.format(cents: data.balance))
                .font(.system(size: 36, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func actionCards(_ data: HomeData) -> some View {
        HStack(spacing: 16) {
            NavigationLink {
                DepositView(homeData: data)
            } label: {
                ActionCard(title: "Deposit Funds", systemImage: "arrow.down.circle.fill")
            }
            .accessibilityIdentifier(DXA.depositOpen)

            NavigationLink {
                PaymentView(homeData: data)
            } label: {
                ActionCard(title: "Send Payment", systemImage: "arrow.up.circle.fill")
            }
            .accessibilityIdentifier(DXA.paymentOpen)
        }
    }

    @ViewBuilder
    private func transactionSection(_ data: HomeData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                NavigationLink("See all") {
                    TransactionListView(
                        transactions: data.history,
                        accountId: data.accountId
                    )
                }
            }

            if data.history.isEmpty {
                Text("No transactions yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(data.history.prefix(5))) { transaction in
                    TransactionRow(transaction: transaction, accountId: data.accountId)
                }
            }
        }
    }

    private func reload() async {
        guard let token = auth.token else { return }
        await homeStore.load(token: token)
    }
}

private struct ActionCard: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title)
            Text(title)
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
        .background(Color.accentColor.opacity(0.12))
        .cornerRadius(12)
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    let accountId: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.accountLabel ?? "Transfer")
                    .font(.subheadline.weight(.semibold))
                Text("\(TransactionFormatter.month(from: transaction.timestamp)) \(TransactionFormatter.day(from: transaction.timestamp))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(signedAmount)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isCredit ? .green : .primary)
        }
        .padding(.vertical, 8)
    }

    private var isCredit: Bool {
        transaction.toAccountNum == accountId
    }

    private var signedAmount: String {
        let cents = isCredit ? transaction.amount : -transaction.amount
        return CurrencyFormatter.format(cents: cents)
    }
}
