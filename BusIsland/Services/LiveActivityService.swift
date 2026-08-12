import ActivityKit
import Foundation

public enum LiveActivityServiceError: Error, LocalizedError, Sendable {
    case activitiesDisabled
    case noActiveActivity
    case updateFailed(String)

    public var errorDescription: String? {
        switch self {
        case .activitiesDisabled:
            return "이 기기에서 Live Activities가 비활성화되어 있습니다."
        case .noActiveActivity:
            return "업데이트할 Live Activity가 없습니다."
        case .updateFailed(let message):
            return message
        }
    }
}

@MainActor
public final class LiveActivityService {
    public private(set) var activeActivityID: String?

    public init() {}

    public var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    public var hasActiveActivity: Bool {
        !Activity<BusRideActivityAttributes>.activities.isEmpty
    }

    public func start(with snapshot: BusRideSnapshot) throws {
        guard areActivitiesEnabled else {
            throw LiveActivityServiceError.activitiesDisabled
        }

        // Design decision: keep a single ride visible by ending any previous prototype activity.
        for activity in Activity<BusRideActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        let attributes = BusRideActivityAttributes(rideID: snapshot.id)
        let content = ActivityContent(state: snapshot.activityState, staleDate: nil)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            activeActivityID = activity.id
        } catch {
            throw LiveActivityServiceError.updateFailed(error.localizedDescription)
        }
    }

    public func update(with snapshot: BusRideSnapshot) async throws {
        guard let activity = Activity<BusRideActivityAttributes>.activities.first else {
            throw LiveActivityServiceError.noActiveActivity
        }

        let content = ActivityContent(state: snapshot.activityState, staleDate: nil)
        await activity.update(content)
        activeActivityID = activity.id
    }

    public func end() async {
        for activity in Activity<BusRideActivityAttributes>.activities {
            let content = ActivityContent(state: activity.content.state, staleDate: nil)
            await activity.end(content, dismissalPolicy: .immediate)
        }
        activeActivityID = nil
    }
}
