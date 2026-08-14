import ActivityKit
import Foundation

public struct BusRideActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var routeNumber: String
        public var destination: String
        public var remainingStops: Int

        public init(routeNumber: String, destination: String, remainingStops: Int) {
            self.routeNumber = routeNumber
            self.destination = destination
            self.remainingStops = remainingStops
        }

        /// Compact Dynamic Island trailing: the updating value only.
        public var compactTrailingText: String {
            "\(remainingStops)"
        }

        /// Minimal Dynamic Island: the glance value.
        public var minimalDisplayText: String {
            "\(remainingStops)"
        }

        /// Expanded trailing / lock-screen unit label.
        public var remainingStopsUnit: String {
            "정거장"
        }
    }

    public var rideID: String

    public init(rideID: String) {
        self.rideID = rideID
    }
}

public extension BusRideActivityAttributes.ContentState {
    static let prototype = BusRideActivityAttributes.ContentState(
        routeNumber: "3412",
        destination: "인덕원역4호선.인덕원성당",
        remainingStops: 9
    )
}
