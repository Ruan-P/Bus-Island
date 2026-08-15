import Foundation

public struct BusRideSnapshot: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var routeNumber: String
    public var boarding: String
    public var destination: String
    public var currentStation: String?
    public var boardingRemainingStops: Int
    public var remainingStops: Int
    public var totalRideStops: Int

    public init(
        id: String = UUID().uuidString,
        routeNumber: String,
        boarding: String = "",
        destination: String,
        currentStation: String? = nil,
        boardingRemainingStops: Int = 0,
        remainingStops: Int,
        totalRideStops: Int = 0
    ) {
        self.id = id
        self.routeNumber = routeNumber
        self.boarding = boarding
        self.destination = destination
        self.currentStation = currentStation
        self.boardingRemainingStops = boardingRemainingStops
        self.remainingStops = remainingStops
        self.totalRideStops = totalRideStops
    }

    public var isOnBoard: Bool {
        boardingRemainingStops <= 0
    }

    public var activeRemainingStops: Int {
        isOnBoard ? remainingStops : boardingRemainingStops
    }

    public var activeStationName: String {
        if let currentStation, !currentStation.isEmpty {
            return currentStation
        }
        return isOnBoard ? destination : (boarding.isEmpty ? destination : boarding)
    }

    public var activityState: BusRideActivityAttributes.ContentState {
        .init(
            routeNumber: routeNumber,
            boarding: boarding,
            destination: destination,
            currentStation: currentStation,
            boardingRemainingStops: boardingRemainingStops,
            remainingStops: remainingStops,
            totalRideStops: totalRideStops
        )
    }

    public static let prototype = BusRideSnapshot(
        id: "prototype-ride",
        routeNumber: "3412",
        boarding: "의왕역",
        destination: "사당역",
        currentStation: "의왕역",
        boardingRemainingStops: 2,
        remainingStops: 6,
        totalRideStops: 8
    )
}
