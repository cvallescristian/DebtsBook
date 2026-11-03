import SwiftUI

/// Setup steps for the Shortcuts automation that feeds LogApplePayPaymentIntent.
/// Apps can't create personal automations themselves, so the user does this once.
struct ApplePayImportView: View {

    private let steps = [
        "Open the Shortcuts app and go to the Automation tab.",
        "Tap + (New Automation) and choose Transaction.",
        "Select all your cards, keep every category, and choose Run Immediately. Tap Next.",
        "Tap New Blank Automation, search for DebtsBook, and add \"Log Apple Pay Payment\".",
        "Tap Merchant and choose Shortcut Input › Merchant. Do the same for Amount (Shortcut Input › Amount) and Card (Shortcut Input › Card or Pass).",
        "Tap Done.",
    ]

    var body: some View {
        Form {
            Section {
                Text("Each Apple Pay payment you make with this iPhone or a paired Apple Watch is added to Expenses › Pending, ready to log or dismiss.")
            }
            Section("Set Up Once") {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Label {
                        Text(step)
                    } icon: {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundStyle(.tint)
                    }
                }
                Button("Open Shortcuts") {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            Section {
                Text("Only Apple Pay payments are captured, not physical card or bank transfers. Payments stay on this device and are never uploaded.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Apple Pay Import")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ApplePayImportView()
    }
}
