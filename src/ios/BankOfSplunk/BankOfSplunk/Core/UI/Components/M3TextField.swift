import SwiftUI

struct M3TextField: View {
    let label: String
    @Binding var text: String
    var systemImage: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppTypography.labelMedium)
                .foregroundStyle(isFocused ? AppColors.primary : AppColors.onSurfaceVariant)

            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(isFocused ? AppColors.primary : AppColors.onSurfaceVariant)
                }
                TextField(label, text: $text)
                    .font(AppTypography.bodyLarge)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .focused($isFocused)
                    .onSubmit { onSubmit?() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppColors.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: AppShape.small))
            .overlay {
                RoundedRectangle(cornerRadius: AppShape.small)
                    .stroke(isFocused ? AppColors.primary : AppColors.outlineVariant, lineWidth: isFocused ? 2 : 1)
            }
        }
        .animation(AppMotion.decelerate, value: isFocused)
    }
}

struct M3SecureField: View {
    let label: String
    @Binding var text: String
    var systemImage: String? = "lock"
    var textContentType: UITextContentType? = .password
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppTypography.labelMedium)
                .foregroundStyle(isFocused ? AppColors.primary : AppColors.onSurfaceVariant)

            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(isFocused ? AppColors.primary : AppColors.onSurfaceVariant)
                }
                SecureField(label, text: $text)
                    .font(AppTypography.bodyLarge)
                    .textContentType(textContentType)
                    .submitLabel(submitLabel)
                    .focused($isFocused)
                    .onSubmit { onSubmit?() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppColors.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: AppShape.small))
            .overlay {
                RoundedRectangle(cornerRadius: AppShape.small)
                    .stroke(isFocused ? AppColors.primary : AppColors.outlineVariant, lineWidth: isFocused ? 2 : 1)
            }
        }
        .animation(AppMotion.decelerate, value: isFocused)
    }
}
