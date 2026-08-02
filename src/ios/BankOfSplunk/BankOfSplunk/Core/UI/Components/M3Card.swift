import SwiftUI

struct M3Card<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                Text(title)
                    .font(AppTypography.titleMedium)
                    .foregroundStyle(AppColors.onSurface)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: AppShape.medium))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

struct M3ActionTile: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(AppColors.primary)
            Text(title)
                .font(AppTypography.labelMedium)
                .foregroundStyle(AppColors.onSurface)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(12)
        .background(AppColors.primaryContainer.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: AppShape.medium))
        .overlay {
            RoundedRectangle(cornerRadius: AppShape.medium)
                .stroke(AppColors.outlineVariant.opacity(0.5), lineWidth: 1)
        }
    }
}
