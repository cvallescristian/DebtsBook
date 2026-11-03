import Foundation
import SwiftData

/// An Apple Pay payment captured by the Shortcuts "Transaction" automation, waiting to be
/// turned into a real Expense or dismissed. Local only: never synced or backed up.
@Model
class PendingExpense {
    var merchant: String = ""
    var amount: Decimal = 0
    var cardName: String?
    var date: Date = Date()

    init(merchant: String, amount: Decimal, cardName: String? = nil, date: Date = Date()) {
        self.merchant = merchant
        self.amount = amount
        self.cardName = cardName
        self.date = date
    }

    /// Shortcuts passes the amount as formatted text ("$12.50", "NZ$1,234.50", "12,50 €").
    /// The last "." or "," is the decimal separator when two or fewer digits follow it.
    static func parseAmount(_ text: String) -> Decimal? {
        let kept = text.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard kept.contains(where: \.isNumber) else { return nil }

        var integerPart = kept
        var fractionPart = ""
        if let separator = kept.lastIndex(where: { $0 == "." || $0 == "," }) {
            let fraction = kept[kept.index(after: separator)...]
            if fraction.count <= 2 {
                integerPart = String(kept[..<separator])
                fractionPart = String(fraction)
            }
        }
        let digits = integerPart.filter(\.isNumber)
        let normalized = fractionPart.isEmpty ? digits : "\(digits.isEmpty ? "0" : digits).\(fractionPart)"
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Inserts a pending expense unless the same payment was already logged within a minute
    /// (an automation can fire twice, e.g. phone and watch). Returns whether it was added.
    @discardableResult
    static func add(merchant: String, amount: Decimal, cardName: String?, date: Date = Date(), to context: ModelContext) -> Bool {
        let window = date.addingTimeInterval(-60)...date.addingTimeInterval(60)
        let existing = (try? context.fetch(FetchDescriptor<PendingExpense>())) ?? []
        let isDuplicate = existing.contains {
            $0.merchant == merchant && $0.amount == amount && window.contains($0.date)
        }
        guard !isDuplicate else { return false }
        context.insert(PendingExpense(merchant: merchant, amount: amount, cardName: cardName, date: date))
        try? context.save()
        return true
    }
}
