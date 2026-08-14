import ActivityKit
import Foundation

public struct BusRideActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var routeNumber: String
        public var boarding: String
        public var destination: String
        /// Stops until the bus reaches the boarding stop.
        public var boardingRemainingStops: Int
        /// Stops until the bus reaches the alighting stop.
        public var remainingStops: Int

        public init(
            routeNumber: String,
            boarding: String = "",
            destination: String,
            boardingRemainingStops: Int = 0,
            remainingStops: Int
        ) {
            self.routeNumber = routeNumber
            self.boarding = boarding
            self.destination = destination
            self.boardingRemainingStops = boardingRemainingStops
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
        boarding: "의왕역",
        destination: "인덕원역4호선.인덕원성당",
        boardingRemainingStops: 2,
        remainingStops: 9
    )
}
