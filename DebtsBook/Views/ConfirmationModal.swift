import SwiftUI

private struct ConfirmationModal: View {

    let title: String
    let message: String
    let confirmLabel: String
    let successMessage: String
    let isDestructive: Bool
    let onConfirm: (() -> Void)?
    let onConfirmAsync: (() async -> Bool)?

    @State private var showingSuccess = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if showingSuccess {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                    Text(successMessage)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal)

                    VStack(spacing: 8) {
                        Button(confirmLabel, role: isDestructive ? .destructive : nil) {
                            confirmTapped()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isDestructive ? .red : .accentColor)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)

                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingSuccess)
        .presentationDetents([.height(230)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(showingSuccess)
    }

    private func confirmTapped() {
        if let onConfirmAsync {
            Task {
                let succeeded = await onConfirmAsync()
                if succeeded {
                    showSuccessThenDismiss()
                } else {
                    dismiss()
                }
            }
        } else {
            onConfirm?()
            showSuccessThenDismiss()
        }
    }

    private func showSuccessThenDismiss() {
        showingSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            dismiss()
        }
    }
}

extension View {
    func confirmationModal(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmLabel: String = "Confirm",
        successMessage: String,
        isDestructive: Bool = true,
        onConfirm: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            ConfirmationModal(title: title, message: message, confirmLabel: confirmLabel, successMessage: successMessage, isDestructive: isDestructive, onConfirm: onConfirm, onConfirmAsync: nil)
        }
    }

    /// Variant for confirmations whose action can fail (e.g. a network call). Success is only
    /// shown when the closure returns `true`; on `false` the sheet dismisses silently so the
    /// caller can surface the failure itself instead of falsely reporting success.
    func confirmationModal(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmLabel: String = "Confirm",
        successMessage: String,
        isDestructive: Bool = true,
        onConfirm: @escaping () async -> Bool,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            ConfirmationModal(title: title, message: message, confirmLabel: confirmLabel, successMessage: successMessage, isDestructive: isDestructive, onConfirm: nil, onConfirmAsync: onConfirm)
        }
    }
}


#Preview {
    Color.clear
        .confirmationModal(isPresented: .constant(true), title: "Delete all expenses?", message: "This action cannot be undone.", confirmLabel: "Delete All Expenses", successMessage: "All expenses deleted") {}
}
