import ActivityKit
import Foundation

public struct BusRideActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var routeNumber: String
        public var boarding: String
        public var destination: String
        /// Stops until the bus reaches the boarding stop (0 = arrived / on board).
        public var boardingRemainingStops: Int
        /// Stops until the bus reaches the destination/alighting stop.
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

        /// Whether the user has boarded the bus and is heading towards the destination.
        public var isOnBoard: Bool {
            boardingRemainingStops <= 0
        }

        /// The primary prominent count to display based on current phase.
        public var activeRemainingStops: Int {
            isOnBoard ? remainingStops : boardingRemainingStops
        }

        /// Short phase indicator title.
        public var phaseTitle: String {
            if !isOnBoard {
                return boardingRemainingStops <= 1 ? "곧 도착" : "승차 대기"
            } else {
                return remainingStops <= 1 ? "하차 준비" : "이동 중"
            }
        }

        /// Compact Dynamic Island trailing text (e.g., "승차 3" or "하차 4").
        public var compactTrailingText: String {
            if !isOnBoard {
                return "\(boardingRemainingStops)전"
            } else {
                return "\(remainingStops)"
            }
        }

        /// Minimal Dynamic Island text.
        public var minimalDisplayText: String {
            "\(activeRemainingStops)"
        }
    }

    public var rideID: String

    public init(rideID: String) {
        self.rideID = rideID
    }
}

public extension BusRideActivityAttributes.ContentState {
    static let prototypeWaiting = BusRideActivityAttributes.ContentState(
        routeNumber: "3412",
        boarding: "의왕역",
        destination: "인덕원역4호선",
        boardingRemainingStops: 3,
        remainingStops: 8
    )

    static let prototypeRiding = BusRideActivityAttributes.ContentState(
        routeNumber: "3412",
        boarding: "의왕역",
        destination: "인덕원역4호선",
        boardingRemainingStops: 0,
        remainingStops: 3
    )
}
