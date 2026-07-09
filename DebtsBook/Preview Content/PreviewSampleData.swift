import Foundation
import SwiftData

@MainActor
enum PreviewSampleData {

    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: Friend.self, Expense.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )

        let cristian = Friend(name: "Cristian")
        let ana = Friend(name: "Ana")
        container.mainContext.insert(cristian)
        container.mainContext.insert(ana)

        container.mainContext.insert(Expense(title: "Groceries", amount: 42.50, friend: cristian, paidByMe: true))
        container.mainContext.insert(Expense(title: "Movie tickets", amount: 18, friend: cristian, paidByMe: false))
        container.mainContext.insert(Expense(title: "Dinner", amount: 30, friend: ana, paidByMe: true))

        return container
    }()

    static var friend: Friend {
        try! container.mainContext.fetch(FetchDescriptor<Friend>(sortBy: [SortDescriptor(\.name)])).first!
    }
}
