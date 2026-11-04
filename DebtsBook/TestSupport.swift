import Foundation
import SwiftData

/// Under the unit test host, the real app boots for real (that's how hosted XCTest/swift-testing
/// bundles link against app code) — but SwiftData traps if two separate ModelContainers for the
/// same @Model types are both alive in one process. So the app and the tests share this single
/// in-memory container instead of each creating their own.
enum TestModelContainer {
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// Set only by DebtsBookUITests: the app runs against a throwaway in-memory store with
    /// seeded data and never restores a Supabase session, so UI tests can't touch real data.
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")

    static let shared: ModelContainer = {
        try! ModelContainer(
            for: Schema(AppModelContainer.modelTypes),
            configurations: .init(isStoredInMemoryOnly: true)
        )
    }()

    static func makeUITestContainer() -> ModelContainer {
        let container = try! ModelContainer(
            for: Schema(AppModelContainer.modelTypes),
            configurations: .init(isStoredInMemoryOnly: true)
        )
        container.mainContext.insert(PendingExpense(merchant: "Countdown", amount: Decimal(string: "42.50")!, cardName: "Visa"))
        if ProcessInfo.processInfo.arguments.contains("-accountSwitch") {
            let friend = Friend(name: "Sam")
            container.mainContext.insert(friend)
            container.mainContext.insert(Expense(title: "Dinner", amount: 30, friend: friend))
        }
        try? container.mainContext.save()
        return container
    }
}
