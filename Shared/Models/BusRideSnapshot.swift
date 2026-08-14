import Foundation

public struct BusRideSnapshot: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var routeNumber: String
    public var boarding: String
    public var destination: String
    public var boardingRemainingStops: Int
    public var remainingStops: Int

    public init(
        id: String = UUID().uuidString,
        routeNumber: String,
        boarding: String = "",
        destination: String,
        boardingRemainingStops: Int = 0,
        remainingStops: Int
    ) {
        self.id = id
        self.routeNumber = routeNumber
        self.boarding = boarding
        self.destination = destination
        self.boardingRemainingStops = boardingRemainingStops
        self.remainingStops = remainingStops
    }

    public var activityState: BusRideActivityAttributes.ContentState {
        .init(
            routeNumber: routeNumber,
            boarding: boarding,
            destination: destination,
            boardingRemainingStops: boardingRemainingStops,
            remainingStops: remainingStops
        )
    }

    public static let prototype = BusRideSnapshot(
        id: "prototype-ride",
        routeNumber: "3412",
        boarding: "의왕역",
        destination: "사당역",
        remainingStops: 4
    )
}
