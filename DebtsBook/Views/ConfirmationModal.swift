import SwiftUI

private struct ConfirmationModal: View {

    let title: String
    let message: String
    let confirmLabel: String
    let isDestructive: Bool
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
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
                    dismiss()
                    onConfirm()
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
        .presentationDetents([.height(230)])
        .presentationDragIndicator(.visible)
    }
}

extension View {
    func confirmationModal(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmLabel: String = "Confirm",
        isDestructive: Bool = true,
        onConfirm: @escaping () -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            ConfirmationModal(title: title, message: message, confirmLabel: confirmLabel, isDestructive: isDestructive, onConfirm: onConfirm)
        }
    }
}


#Preview {
    Color.clear
        .confirmationModal(isPresented: .constant(true), title: "Delete all activity?", message: "This action cannot be undone.", confirmLabel: "Delete All Activity") {}
}
