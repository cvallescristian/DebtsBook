import Foundation
import UIKit
import UserNotifications
import Supabase

private struct DeviceTokenUpsert: Encodable {
    let token: String
    let user_id: UUID
    let env: String
    let notify_expense_changes: Bool
    let notify_paid: Bool
    let notify_settled_up: Bool
}

private struct DevicePreferencesUpdate: Encodable {
    let notify_expense_changes: Bool
    let notify_paid: Bool
    let notify_settled_up: Bool
}

/// Push notifications are sent server-side (supabase/functions/notify-activity) to every
/// token in `device_tokens`; this only manages permission and keeps this device's row current.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    static let enabledKey = "notifyFriendChanges"
    static let expenseChangesKey = "notifyExpenseChanges"
    static let paidKey = "notifyPaid"
    static let settledUpKey = "notifySettledUp"
    private static let tokenKey = "apnsDeviceToken"

    private let client = SupabaseManager.shared.client

    #if DEBUG
    private let apnsEnvironment = "sandbox"
    #else
    private let apnsEnvironment = "production"
    #endif

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // Without this iOS drops the banner while the app is in the foreground.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let route = NotificationRoute(userInfo: response.notification.request.content.userInfo)
        await MainActor.run { NotificationRouter.shared.pendingRoute = route }
    }

    func enable() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    func disable() async {
        await removeDeviceToken()
    }

    /// APNs tokens can change between launches, so re-register whenever a session starts.
    func registerIfEnabled() {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func save(deviceToken: Data) async {
        let token = Self.hexString(from: deviceToken)
        UserDefaults.standard.set(token, forKey: Self.tokenKey)
        guard UserDefaults.standard.bool(forKey: Self.enabledKey),
              let userID = AuthService.shared.syncUserID else { return }
        let preferences = Self.preferences
        let upsert = DeviceTokenUpsert(
            token: token,
            user_id: userID,
            env: apnsEnvironment,
            notify_expense_changes: preferences.notify_expense_changes,
            notify_paid: preferences.notify_paid,
            notify_settled_up: preferences.notify_settled_up
        )
        try? await client.from("device_tokens").upsert(upsert, onConflict: "token").execute()
    }

    /// Sends this device's per-type switches; the server skips pushes they turn off.
    func updatePreferences() async {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey),
              let token = UserDefaults.standard.string(forKey: Self.tokenKey) else { return }
        try? await client.from("device_tokens").update(Self.preferences).eq("token", value: token).execute()
    }

    /// Each switch defaults to on, matching the server columns.
    static func isEnabled(_ key: String, in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
    }

    private static var preferences: DevicePreferencesUpdate {
        DevicePreferencesUpdate(
            notify_expense_changes: isEnabled(expenseChangesKey),
            notify_paid: isEnabled(paidKey),
            notify_settled_up: isEnabled(settledUpKey)
        )
    }

    /// APNs expects the token as lowercase hex in the request path.
    static func hexString(from deviceToken: Data) -> String {
        deviceToken.map { String(format: "%02x", $0) }.joined()
    }

    /// Must run before sign-out: RLS only lets the owning user delete the row.
    func removeDeviceToken() async {
        guard let token = UserDefaults.standard.string(forKey: Self.tokenKey) else { return }
        try? await client.from("device_tokens").delete().eq("token", value: token).execute()
    }
}
