import Testing
import Foundation
@testable import DebtsBook

struct NotificationServiceTests {

    @Test func deviceTokenIsLowercaseHex() {
        let token = Data([0x00, 0x0f, 0xab, 0xff])
        #expect(NotificationService.hexString(from: token) == "000fabff")
    }

    @Test func fullLengthTokenKeepsEveryByte() {
        let token = Data(repeating: 0x7e, count: 32)
        #expect(NotificationService.hexString(from: token).count == 64)
    }

    @Test func preferenceSwitchesDefaultToOn() {
        let defaults = UserDefaults(suiteName: "NotificationServiceTests")!
        defaults.removePersistentDomain(forName: "NotificationServiceTests")
        #expect(NotificationService.isEnabled(NotificationService.paidKey, in: defaults))
        defaults.set(false, forKey: NotificationService.paidKey)
        #expect(!NotificationService.isEnabled(NotificationService.paidKey, in: defaults))
    }
}
