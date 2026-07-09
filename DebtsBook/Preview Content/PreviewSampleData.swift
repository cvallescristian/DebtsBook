import Foundation
import SwiftData

@MainActor
enum PreviewSampleData {

    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: Friend.self, Expense.self, Activity.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )

        let cristian = Friend(name: "Cristian")
        let ana = Friend(name: "Ana")
        container.mainContext.insert(cristian)
        container.mainContext.insert(ana)

        let groceries = Expense(title: "Groceries", amount: 42.50, friend: cristian, paidByMe: true, comment: "Split for the weekend BBQ")
        let movieTickets = Expense(title: "Movie tickets", amount: 18, friend: cristian, paidByMe: false)
        let dinner = Expense(title: "Dinner", amount: 30, friend: ana, paidByMe: true)
        let coffee = Expense(title: "Coffee", amount: 5.5)
        container.mainContext.insert(groceries)
        container.mainContext.insert(movieTickets)
        container.mainContext.insert(dinner)
        container.mainContext.insert(coffee)

        container.mainContext.insert(Activity(type: .created, expenseTitle: groceries.title, friendName: cristian.name, amount: groceries.owedAmount, paidByMe: groceries.paidByMe, expense: groceries, friend: cristian))
        container.mainContext.insert(Activity(type: .created, expenseTitle: movieTickets.title, friendName: cristian.name, amount: movieTickets.owedAmount, paidByMe: movieTickets.paidByMe, expense: movieTickets, friend: cristian, date: Date().addingTimeInterval(-3600 * 8)))
        container.mainContext.insert(Activity(type: .created, expenseTitle: dinner.title, friendName: ana.name, amount: dinner.owedAmount, paidByMe: dinner.paidByMe, expense: dinner, friend: ana, date: Date().addingTimeInterval(-3600 * 20)))
        container.mainContext.insert(Activity(type: .created, expenseTitle: coffee.title, amount: coffee.amount, paidByMe: true, expense: coffee))

        return container
    }()

    static var friend: Friend {
        try! container.mainContext.fetch(FetchDescriptor<Friend>(sortBy: [SortDescriptor(\.name)])).first!
    }
}
