import SwiftUI

struct TransactionListView: View {
    let transactions: [Transaction]
    let accountId: String

    var body: some View {
        List(transactions) { transaction in
            TransactionRow(transaction: transaction, accountId: accountId)
        }
        .navigationTitle("Transactions")
        .onAppear {
            BankRum.trackScreen(DXA.transactionsPage, component: DXA.accountNavComponent)
        }
    }
}
