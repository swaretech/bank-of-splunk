import SwiftUI

struct M3TransactionRow: View {
    let transaction: Transaction
    let accountId: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.accountLabel ?? "Transfer")
                    .font(AppTypography.titleSmall)
                    .foregroundStyle(AppColors.onSurface)
                    .dxaSensitiveContent()
                Text("\(TransactionFormatter.month(from: transaction.timestamp)) \(TransactionFormatter.day(from: transaction.timestamp))")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.onSurfaceVariant)
            }
            Spacer()
            Text(signedAmount)
                .font(AppTypography.titleSmall)
                .foregroundStyle(isCredit ? AppColors.credit : AppColors.onSurface)
                .dxaSensitiveContent()
        }
        .padding(.vertical, 10)
    }

    private var isCredit: Bool {
        transaction.toAccountNum == accountId
    }

    private var signedAmount: String {
        let cents = isCredit ? transaction.amount : -transaction.amount
        return CurrencyFormatter.format(cents: cents)
    }
}
