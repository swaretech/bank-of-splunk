import SwiftUI

struct TransactionListView: View {
    let transactions: [Transaction]
    let accountId: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("All Transactions")
                    .font(AppTypography.titleMedium)
                    .foregroundStyle(AppColors.onSurface)

                if transactions.isEmpty {
                    Text("No transactions yet.")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.onSurfaceVariant)
                } else {
                    M3Card {
                        VStack(spacing: 0) {
                            ForEach(transactions) { transaction in
                                M3TransactionRow(transaction: transaction, accountId: accountId)
                                if transaction.id != transactions.last?.id {
                                    Divider()
                                        .background(AppColors.outlineVariant)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppColors.surface)
        .navigationTitle("Transactions")
        .onAppear {
            BankRum.trackScreen(DXA.transactionsPage, component: DXA.accountNavComponent)
        }
    }
}
