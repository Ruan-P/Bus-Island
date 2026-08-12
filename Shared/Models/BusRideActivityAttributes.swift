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

        public var compactTrailingText: String {
            "\(destination) \(remainingStops)정거장"
        }

        public var remainingStopsLabel: String {
            "\(remainingStops)정거장"
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
        destination: "사당역",
        remainingStops: 4
    )
}
