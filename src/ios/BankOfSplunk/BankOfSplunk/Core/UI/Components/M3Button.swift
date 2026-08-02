import SwiftUI

struct M3FilledButton: View {
    let title: String
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(AppColors.onPrimary)
                } else {
                    Text(title)
                        .font(AppTypography.labelLarge)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppColors.onPrimary)
        .background(isDisabled ? AppColors.onSurfaceVariant.opacity(0.38) : AppColors.primary)
        .clipShape(RoundedRectangle(cornerRadius: AppShape.full))
        .disabled(isDisabled || isLoading)
        .m3PressScale()
        .animation(AppMotion.standardSpring, value: isLoading)
    }
}

struct M3OutlinedButton: View {
    let title: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.labelLarge)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDisabled ? AppColors.onSurfaceVariant : AppColors.primary)
        .overlay {
            RoundedRectangle(cornerRadius: AppShape.full)
                .stroke(AppColors.outline, lineWidth: 1)
        }
        .disabled(isDisabled)
        .m3PressScale()
    }
}

struct M3TextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.labelLarge)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppColors.primary)
        .m3PressScale()
    }
}
