import Foundation
import UserNotifications

@MainActor
final class RideNotificationService {
    static let shared = RideNotificationService()

    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            AppLog.log("notification permission=\(granted)")
        } catch {
            AppLog.log("notification permission error: \(error.localizedDescription)")
        }
    }

    func notifyBoardingSoon(route: String, station: String) {
        post(
            id: "ride.boarding.soon",
            title: "\(route) 승차 1정거장",
            body: "\(station)에서 승차하세요. 앱에서 승차를 눌러 주세요."
        )
    }

    func notifyAlightSoon(route: String, station: String) {
        post(
            id: "ride.alight.soon",
            title: "\(route) 하차 1정거장",
            body: "다음 정류장은 \(station)입니다. 내릴 준비 하세요."
        )
    }

    func notifyArrived(route: String, station: String) {
        post(
            id: "ride.alight.now",
            title: "\(route) 하차하세요",
            body: "\(station)에 도착했습니다."
        )
    }

    func clearRideNotifications() {
        center.removeDeliveredNotifications(withIdentifiers: [
            "ride.boarding.soon",
            "ride.alight.soon",
            "ride.alight.now",
        ])
        center.removePendingNotificationRequests(withIdentifiers: [
            "ride.boarding.soon",
            "ride.alight.soon",
            "ride.alight.now",
        ])
    }

    private func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error {
                AppLog.log("notification \(id) failed: \(error.localizedDescription)")
            } else {
                AppLog.log("notification \(id) posted")
            }
        }
    }
}
