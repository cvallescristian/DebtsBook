import SwiftUI

private struct SplitOption: Identifiable {
    let paidByMe: Bool
    let splitType: SplitType
    var id: String { "\(paidByMe)-\(splitType.rawValue)" }
}

struct SplitOptionsPicker: View {

    let amount: Decimal
    let friendName: String
    @Binding var paidByMe: Bool
    @Binding var splitType: SplitType

    private let options: [SplitOption] = [
        SplitOption(paidByMe: true, splitType: .equally),
        SplitOption(paidByMe: true, splitType: .fullAmount),
        SplitOption(paidByMe: false, splitType: .equally),
        SplitOption(paidByMe: false, splitType: .fullAmount),
    ]

    private func title(for option: SplitOption) -> String {
        switch (option.paidByMe, option.splitType) {
        case (true, .equally): return "You paid, split equally."
        case (true, .fullAmount): return "You are owed the full amount."
        case (false, .equally): return "\(friendName) paid, split equally."
        case (false, .fullAmount): return "\(friendName) is owed the full amount."
        }
    }

    private func resultText(for option: SplitOption) -> String {
        let owedAmount = option.splitType == .equally ? amount / 2 : amount
        let formatted = owedAmount.formatted(.currency(code: "NZD"))
        return option.paidByMe ? "\(friendName) owes you \(formatted)." : "You owe \(friendName) \(formatted)."
    }

    var body: some View {
        ForEach(options) { option in
            Button {
                paidByMe = option.paidByMe
                splitType = option.splitType
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(for: option))
                            .foregroundStyle(.primary)
                        Text(resultText(for: option))
                            .foregroundColor(option.paidByMe ? .green : .red)
                    }
                    Spacer()
                    if paidByMe == option.paidByMe && splitType == option.splitType {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}


#Preview {
    @Previewable @State var paidByMe = true
    @Previewable @State var splitType: SplitType = .equally

    List {
        Section("How was this expense split?") {
            SplitOptionsPicker(amount: 100, friendName: "alumnos_uv", paidByMe: $paidByMe, splitType: $splitType)
        }
    }
}
