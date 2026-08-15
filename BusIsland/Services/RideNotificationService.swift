import Foundation
import UserNotifications

@MainActor
final class RideNotificationService {
    static let shared = RideNotificationService()

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            AppLog.log("notification permission=\(granted)")
        } catch {
            AppLog.log("notification permission error: \(error.localizedDescription)")
        }
    }

    func notifyBoardingSoon(route: String, station: String) {
        post(
            id: "ride.boarding.soon",
            title: "🚌 \(route) 승차 1정거장",
            body: "\(station)에서 승차하세요. 앱에서 승차를 눌러 주세요."
        )
    }

    func notifyAlightSoon(route: String, station: String) {
        post(
            id: "ride.alight.soon",
            title: "🔔 \(route) 하차 1정거장",
            body: "다음 정류장은 \(station)입니다. 내릴 준비 하세요."
        )
    }

    func notifyArrived(route: String, station: String) {
        post(
            id: "ride.alight.now",
            title: "🏁 \(route) 하차하세요",
            body: "\(station)에 도착했습니다."
        )
    }

    func clearRideNotifications() {
        let ids = [
            "ride.boarding.soon",
            "ride.alight.soon",
            "ride.alight.now",
        ]
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: ids)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        // Attach custom App Icon image to bypass sideloading SpringBoard icon cache
        if let attachment = Self.createAppIconAttachment() {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            Task { @MainActor in
                if let error {
                    AppLog.log("notification \(id) failed: \(error.localizedDescription)")
                } else {
                    AppLog.log("notification \(id) posted with custom icon attachment")
                }
            }
        }
    }

    private static func createAppIconAttachment() -> UNNotificationAttachment? {
        guard let sourceURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png")
                ?? Bundle.main.url(forResource: "AppIcon60x60@3x", withExtension: "png")
                ?? Bundle.main.url(forResource: "AppIcon-1024", withExtension: "png")
        else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let targetURL = tempDir.appendingPathComponent("ta_seom_notification_icon.png")
        try? FileManager.default.removeItem(at: targetURL)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            return try UNNotificationAttachment(identifier: "app_icon_attachment", url: targetURL, options: nil)
        } catch {
            return try? UNNotificationAttachment(identifier: "app_icon_attachment", url: sourceURL, options: nil)
        }
    }
}
