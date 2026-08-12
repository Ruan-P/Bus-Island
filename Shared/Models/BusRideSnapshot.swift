import Foundation

public struct BusRideSnapshot: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var routeNumber: String
    public var destination: String
    public var remainingStops: Int

    public init(
        id: String = UUID().uuidString,
        routeNumber: String,
        destination: String,
        remainingStops: Int
    ) {
        self.id = id
        self.routeNumber = routeNumber
        self.destination = destination
        self.remainingStops = remainingStops
    }

    public var activityState: BusRideActivityAttributes.ContentState {
        .init(
            routeNumber: routeNumber,
            destination: destination,
            remainingStops: remainingStops
        )
    }

    public static let prototype = BusRideSnapshot(
        id: "prototype-ride",
        routeNumber: "3412",
        destination: "사당역",
        remainingStops: 4
    )
}
