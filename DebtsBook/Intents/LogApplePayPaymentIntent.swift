import AppIntents
import SwiftData

private struct InvalidAmountError: Error, CustomLocalizedStringResourceConvertible {
    let amount: String
    var localizedStringResource: LocalizedStringResource { "Couldn't read the amount \"\(amount)\"." }
}

/// Run by a Shortcuts "Transaction" automation after each Apple Pay payment.
struct LogApplePayPaymentIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Apple Pay Payment"
    static let description = IntentDescription("Adds a payment to DebtsBook's pending expenses so you can log it later.")
    static let openAppWhenRun = false

    @Parameter(title: "Merchant")
    var merchant: String

    @Parameter(title: "Amount")
    var amount: String

    @Parameter(title: "Card")
    var card: String?

    // Without a summary, iOS 26 Shortcuts shows the action as a closed card with no fields to link.
    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) at \(\.$merchant)") {
            \.$card
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let value = PendingExpense.parseAmount(amount), value > 0 else {
            throw InvalidAmountError(amount: amount)
        }
        let name = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        PendingExpense.add(
            merchant: name.isEmpty ? "Apple Pay" : name,
            amount: value,
            cardName: card,
            to: AppModelContainer.shared.mainContext
        )
        return .result()
    }
}

struct DebtsBookShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogApplePayPaymentIntent(),
            phrases: ["Log a payment in \(.applicationName)"],
            shortTitle: "Log Apple Pay Payment",
            systemImageName: "creditcard"
        )
    }
}
