import Foundation
import SwiftData

/// The local store belongs to one Supabase account at a time. Syncing a store that belongs to a
/// different account is destructive: pulls for the old account's connections come back empty
/// (RLS) and the reconcile pass deletes every shared expense locally. So nothing syncs until the
/// signed-in account is confirmed as the owner.
enum AccountOwnership {
    static let ownerKey = "dataOwnerUserID"

    enum Decision: Equatable {
        case adopt
        case proceed
        case askToSwitch
    }

    static var owner: String? {
        get { UserDefaults.standard.string(forKey: ownerKey) }
        set { UserDefaults.standard.set(newValue, forKey: ownerKey) }
    }

    static func decide(owner: String?, signedIn: String, hasLocalData: Bool) -> Decision {
        if owner == signedIn {
            return .proceed
        }
        if owner == nil || !hasLocalData {
            return .adopt
        }
        return .askToSwitch
    }

    static func hasLocalData(in context: ModelContext) -> Bool {
        AppModelContainer.modelTypes.contains { type in
            count(of: type, in: context) > 0
        }
    }

    /// Local only: the old account's server data stays intact, and the new account must not
    /// touch it (unlike Reset App, which disconnects friends on the server).
    /// No explicit save: saving here re-renders visible rows synchronously while they still
    /// hold the deleted models, which crashes on the first property read. Autosave commits
    /// after @Query has dropped them.
    static func eraseLocalData(in context: ModelContext) {
        for type in AppModelContainer.modelTypes {
            deleteAll(type, in: context)
        }
    }

    private static func count<T: PersistentModel>(of type: T.Type, in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        let objects = (try? context.fetch(FetchDescriptor<T>())) ?? []
        for object in objects {
            context.delete(object)
        }
    }
}
