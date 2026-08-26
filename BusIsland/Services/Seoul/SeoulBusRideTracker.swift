import Foundation

/// Tracks a selected Seoul Bus ride and produces `BusRideSnapshot` updates for Live Activity.
@MainActor
public final class SeoulBusRideTracker {
    private let client: SeoulBusAPIClient
    private var pollTask: Task<Void, Never>?

    public private(set) var selection: GbisRideSelection?
    public private(set) var latestSnapshot: BusRideSnapshot?
    public private(set) var isOnBoardConfirmed = false
    public private(set) var hasArrived = false
    public private(set) var lastBoardingRemaining: Int?
    public private(set) var lastAlightingRemaining: Int?
    public private(set) var didFireBoardingSoon = false
    public private(set) var didFireAlightSoon = false

    private var pendingEvent: RidePhaseEvent?

    public init(client: SeoulBusAPIClient? = nil) {
        self.client = client ?? SeoulBusAPIClient.shared
    }

    public var isTracking: Bool { pollTask != nil }

    public func consumePhaseEvent() -> RidePhaseEvent? {
        let event = pendingEvent
        pendingEvent = nil
        return event
    }

    public func makeInitialSnapshot(from selection: GbisRideSelection) async throws -> BusRideSnapshot {
        self.selection = selection
        isOnBoardConfirmed = false
        hasArrived = false
        lastBoardingRemaining = nil
        lastAlightingRemaining = nil
        didFireBoardingSoon = false
        didFireAlightSoon = false
        pendingEvent = nil
        return try await refreshSnapshot()
    }

    public func refreshSnapshot() async throws -> BusRideSnapshot {
        guard let selection else {
            throw GbisAPIError.emptyResult
        }
        let seqDiff = max(1, selection.destination.stationSeq - selection.boardingSeq)

        async let boardingLookup = client.remainingStops(
            routeId: selection.route.routeId,
            stationId: selection.boardingStation.stationId,
            stationSeq: selection.boardingSeq
        )
        async let alightingLookup = client.remainingStops(
            routeId: selection.route.routeId,
            stationId: selection.destination.stationId,
            stationSeq: selection.destination.stationSeq
        )
        let (boardingRealtime, alightingRealtime) = await (boardingLookup, alightingLookup)

        applyPhaseTransitions(
            boardingRealtime: boardingRealtime.remainingStops,
            alightingRealtime: alightingRealtime.remainingStops,
            seqDiff: seqDiff
        )

        let boardingStops = isOnBoardConfirmed ? 0 : (boardingRealtime.remainingStops ?? lastBoardingRemaining ?? 0)
        var alightingStops = alightingRealtime.remainingStops ?? lastAlightingRemaining ?? seqDiff
        if hasArrived {
            alightingStops = 0
        }

        var currentStationName: String = ""
        let sortedStations = selection.allStations.sorted { $0.stationSeq < $1.stationSeq }

        if !isOnBoardConfirmed {
            if boardingStops <= 0 {
                currentStationName = "\(selection.boardingStation.stationName) 진입 중"
            } else if !sortedStations.isEmpty {
                let boardingIndex = sortedStations.firstIndex(where: {
                    $0.stationId == selection.boardingStation.stationId || $0.stationSeq == selection.boardingSeq
                })
                if let bIdx = boardingIndex, bIdx - boardingStops >= 0 {
                    currentStationName = sortedStations[bIdx - boardingStops].stationName
                } else {
                    currentStationName = "\(boardingStops)정거장 전 운행 중"
                }
            } else {
                currentStationName = "\(boardingStops)정거장 전 운행 중"
            }
        } else {
            if hasArrived || alightingStops <= 0 {
                currentStationName = "\(selection.destination.stationName) 도착"
            } else if !sortedStations.isEmpty {
                let destIndex = sortedStations.firstIndex(where: {
                    $0.stationId == selection.destination.stationId || $0.stationSeq == selection.destination.stationSeq
                })
                if let dIdx = destIndex, dIdx - alightingStops >= 0 {
                    currentStationName = sortedStations[dIdx - alightingStops].stationName
                } else {
                    currentStationName = "하차 정류장 향해 운행 중"
                }
            } else {
                currentStationName = "하차 정류장 향해 운행 중"
            }
        }

        let totalJourneyStops = max(1, seqDiff)
        let completedStops = totalJourneyStops - alightingStops
        let progress = isOnBoardConfirmed ? min(1.0, max(0.0, Double(completedStops) / Double(totalJourneyStops))) : 0.0

        let snapshot = BusRideSnapshot(
            routeNumber: selection.route.routeName,
            boarding: selection.boardingStation.stationName,
            destination: selection.destination.stationName,
            remainingStops: max(0, alightingStops),
            boardingRemainingStops: max(0, boardingStops),
            totalJourneyStops: totalJourneyStops,
            progress: progress,
            isOnBoard: isOnBoardConfirmed,
            currentStation: currentStationName
        )
        latestSnapshot = snapshot
        return snapshot
    }

    public func confirmBoarding() async throws -> BusRideSnapshot {
        isOnBoardConfirmed = true
        pendingEvent = .boarded
        return try await refreshSnapshot()
    }

    public func startLivePolling(
        intervalSeconds: TimeInterval = 20,
        onUpdate: @escaping (BusRideSnapshot) async -> Void
    ) {
        stopLivePolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                do {
                    let snapshot = try await self.refreshSnapshot()
                    await onUpdate(snapshot)
                } catch {
                    AppLog.log("SeoulBusRideTracker polling error: \(error.localizedDescription)")
                }
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
            }
        }
    }

    public func stopLivePolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func applyPhaseTransitions(
        boardingRealtime: Int?,
        alightingRealtime: Int?,
        seqDiff: Int
    ) {
        if let b = boardingRealtime {
            lastBoardingRemaining = b
            if b <= 1 && !didFireBoardingSoon && !isOnBoardConfirmed {
                didFireBoardingSoon = true
                pendingEvent = .boardingSoon
            }
            if b <= 0 && !isOnBoardConfirmed {
                isOnBoardConfirmed = true
                pendingEvent = .boarded
            }
        }

        if let a = alightingRealtime {
            lastAlightingRemaining = a
            if a <= 1 && !didFireAlightSoon && isOnBoardConfirmed {
                didFireAlightSoon = true
                pendingEvent = .alightSoon
            }
            if a <= 0 && isOnBoardConfirmed {
                hasArrived = true
                pendingEvent = .arrived
            }
        }
    }
}
