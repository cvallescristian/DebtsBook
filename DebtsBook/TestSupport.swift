import Foundation
import SwiftData

/// Under the unit test host, the real app boots for real (that's how hosted XCTest/swift-testing
/// bundles link against app code) — but SwiftData traps if two separate ModelContainers for the
/// same @Model types are both alive in one process. So the app and the tests share this single
/// in-memory container instead of each creating their own.
enum TestModelContainer {
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    static let shared: ModelContainer = {
        try! ModelContainer(
            for: Friend.self, Expense.self, Activity.self, Budget.self, ExpenseGroup.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )
    }()
}
