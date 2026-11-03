import SwiftUI

/// Setup steps for the Shortcuts automation that feeds LogApplePayPaymentIntent.
/// Apps can't create personal automations themselves, so the user does this once.
/// Shortcuts' UI changes between iOS versions, so the full per-version guide lives on the
/// web (docs/apple-pay) where it can be fixed without an app release.
struct ApplePayImportView: View {

    static let guideURL = URL(string: "https://cvallescristian.github.io/DebtsBook/apple-pay/")!

    private let steps = [
        "In Shortcuts, create a personal automation that runs when you pay with any card.",
        "Add DebtsBook's \"Log Apple Pay Payment\" action.",
        "Link Merchant, Amount and Card to the payment's Merchant, Amount and Card or Pass.",
        "Turn the automation on, with Notify off.",
    ]

    var body: some View {
        Form {
            Section {
                Text("Each Apple Pay payment you make is added to Expenses › Pending, ready to log or dismiss.")
            }
            Section {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Label {
                        Text(step)
                    } icon: {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundStyle(.tint)
                    }
                }
                Link(destination: Self.guideURL) {
                    Label("Open Full Guide", systemImage: "safari")
                }
                Button("Open Shortcuts") {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                }
            } header: {
                Text("Set Up Once")
            } footer: {
                Text("The full guide has step-by-step instructions for your iOS version.")
            }
            Section {
                Text("Test with a real Apple Pay payment: the ▶︎ button in Shortcuts runs without one and shows an error. Only Apple Pay payments are captured, not physical cards or bank transfers. Payments stay on this device and are never uploaded.")
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
