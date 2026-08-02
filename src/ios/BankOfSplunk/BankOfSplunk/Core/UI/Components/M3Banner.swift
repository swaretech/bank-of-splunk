import SwiftUI

struct M3Banner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColors.success)
            Text(message)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(AppColors.successContainer)
        .clipShape(RoundedRectangle(cornerRadius: AppShape.medium))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -12)
        .onAppear {
            withAnimation(AppMotion.standardSpring) {
                isVisible = true
            }
        }
    }
}

struct M3ErrorText: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.footnote)
            Text(message)
                .font(AppTypography.bodySmall)
        }
        .foregroundStyle(AppColors.error)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dxaSensitiveContent()
    }
}
