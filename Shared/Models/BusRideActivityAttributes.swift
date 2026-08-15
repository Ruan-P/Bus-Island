import ActivityKit
import Foundation

public struct BusRideActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var routeNumber: String
        public var boarding: String
        public var destination: String
        /// Optional intermediate passing or currently tracked station name.
        public var currentStation: String?
        /// Stops until the bus reaches the boarding stop (0 = arrived / on board).
        public var boardingRemainingStops: Int
        /// Stops until the bus reaches the destination/alighting stop.
        public var remainingStops: Int
        /// Total stop count between boarding and destination (for accurate progress calculation).
        public var totalRideStops: Int

        public init(
            routeNumber: String,
            boarding: String = "",
            destination: String,
            currentStation: String? = nil,
            boardingRemainingStops: Int = 0,
            remainingStops: Int,
            totalRideStops: Int = 0
        ) {
            self.routeNumber = routeNumber
            self.boarding = boarding
            self.destination = destination
            self.currentStation = currentStation
            self.boardingRemainingStops = boardingRemainingStops
            self.remainingStops = remainingStops
            self.totalRideStops = totalRideStops
        }

        /// Whether the user has boarded the bus and is heading towards the destination.
        public var isOnBoard: Bool {
            boardingRemainingStops <= 0
        }

        /// The primary prominent count to display based on current phase.
        public var activeRemainingStops: Int {
            isOnBoard ? remainingStops : boardingRemainingStops
        }

        /// Prominently tracked target station for the active phase (Boarding Stop when waiting, Destination Stop when onboard).
        public var activeStationName: String {
            isOnBoard ? destination : (boarding.isEmpty ? destination : boarding)
        }

        /// Role label for the actively tracked station.
        public var activeStationRole: String {
            isOnBoard ? "하차 정류소" : "승차 정류소"
        }

        /// Dynamic journey progress from 0.0 (far away) to 1.0 (arrived at destination).
        public var progress: Double {
            if !isOnBoard {
                // Phase 1: Waiting for bus (0.08 ~ 0.45)
                let stops = max(0, boardingRemainingStops)
                let factor = max(0.0, 1.0 - (Double(stops) / max(5.0, Double(stops + 1))))
                return min(0.45, max(0.08, 0.08 + factor * 0.37))
            } else {
                // Phase 2: On board heading to destination (0.50 ~ 1.0)
                let total = max(1, totalRideStops > 0 ? totalRideStops : remainingStops + 1)
                let completed = max(0, total - remainingStops)
                let ridingFactor = min(1.0, max(0.0, Double(completed) / Double(total)))
                return min(1.0, max(0.50, 0.50 + ridingFactor * 0.50))
            }
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
        currentStation: "의왕역",
        boardingRemainingStops: 3,
        remainingStops: 8,
        totalRideStops: 8
    )

    static let prototypeRiding = BusRideActivityAttributes.ContentState(
        routeNumber: "3412",
        boarding: "의왕역",
        destination: "인덕원역4호선",
        currentStation: "인덕원역4호선",
        boardingRemainingStops: 0,
        remainingStops: 3,
        totalRideStops: 8
    )
}
