import Foundation
import UIKit
import UserNotifications
import Supabase

private struct DeviceTokenUpsert: Encodable {
    let token: String
    let user_id: UUID
    let env: String
}

/// Push notifications are sent server-side (supabase/functions/notify-activity) to every
/// token in `device_tokens`; this only manages permission and keeps this device's row current.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    static let enabledKey = "notifyFriendChanges"
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
        let upsert = DeviceTokenUpsert(token: token, user_id: userID, env: apnsEnvironment)
        try? await client.from("device_tokens").upsert(upsert, onConflict: "token").execute()
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
