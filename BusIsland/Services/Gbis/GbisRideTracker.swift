import Foundation

enum RidePhaseEvent: Equatable, Sendable {
    case boardingSoon
    case boarded
    case alightSoon
    case arrived
}

/// Tracks a selected GBIS ride and produces `BusRideSnapshot` updates for Live Activity.
@MainActor
final class GbisRideTracker {
    private let client: GbisAPIClient
    private var pollTask: Task<Void, Never>?

    private(set) var selection: GbisRideSelection?
    private(set) var latestSnapshot: BusRideSnapshot?
    private(set) var isOnBoardConfirmed = false
    private(set) var hasArrived = false

    private var lastBoardingRemaining: Int?
    private var lastAlightingRemaining: Int?
    private var didFireBoardingSoon = false
    private var didFireAlightSoon = false
    private var pendingEvent: RidePhaseEvent?

    init(client: GbisAPIClient? = nil) {
        self.client = client ?? GbisAPIClient.shared
    }

    var isTracking: Bool { pollTask != nil }

    func consumePhaseEvent() -> RidePhaseEvent? {
        let event = pendingEvent
        pendingEvent = nil
        return event
    }

    func makeInitialSnapshot(from selection: GbisRideSelection) async throws -> BusRideSnapshot {
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

    func refreshSnapshot() async throws -> BusRideSnapshot {
        guard let selection else {
            throw GbisAPIError.emptyResult
        }
        let city = Self.cityCode(for: selection.boardingStation)
        let seqDiff = max(1, selection.destination.stationSeq - selection.boardingSeq)

        async let boardingLookup = client.remainingStops(
            routeId: selection.route.routeId,
            stationId: selection.boardingStation.stationId,
            cityCode: city
        )
        async let alightingLookup = client.remainingStops(
            routeId: selection.route.routeId,
            stationId: selection.destination.stationId,
            cityCode: city
        )
        let (boardingRealtime, alightingRealtime) = await (boardingLookup, alightingLookup)

        applyPhaseTransitions(
            boardingRealtime: boardingRealtime,
            alightingRealtime: alightingRealtime,
            seqDiff: seqDiff
        )

        let boardingStops = isOnBoardConfirmed ? 0 : (boardingRealtime ?? lastBoardingRemaining ?? 0)
        var alightingStops = alightingRealtime ?? lastAlightingRemaining ?? seqDiff
        if hasArrived {
            alightingStops = 0
        }

        let snapshot = BusRideSnapshot(
            id: selection.rideID,
            routeNumber: selection.route.routeName,
            boarding: selection.boardingStation.stationName,
            destination: selection.destination.stationName,
            boardingRemainingStops: boardingStops,
            remainingStops: alightingStops,
            totalRideStops: seqDiff
        )
        latestSnapshot = snapshot
        AppLog.log(
            "ride refresh boarded=\(isOnBoardConfirmed) arrived=\(hasArrived) board=\(boardingRealtime.map(String.init) ?? "-") dest=\(alightingRealtime.map(String.init) ?? "-") event=\(String(describing: pendingEvent))"
        )
        return snapshot
    }

    func markAsBoarded() -> BusRideSnapshot? {
        guard var current = latestSnapshot else { return nil }
        isOnBoardConfirmed = true
        current.boardingRemainingStops = 0
        latestSnapshot = current
        emit(.boarded)
        return current
    }

    private func applyPhaseTransitions(
        boardingRealtime: Int?,
        alightingRealtime: Int?,
        seqDiff: Int
    ) {
        if !isOnBoardConfirmed {
            // 1. 승차 대기 단계
            if let boarding = boardingRealtime {
                if boarding == 0 {
                    confirmBoarded()
                } else if boarding == 1 {
                    if !didFireBoardingSoon {
                        didFireBoardingSoon = true
                        emit(.boardingSoon)
                    }
                } else if let previous = lastBoardingRemaining, previous <= 1, boarding >= previous + 2 {
                    // 승차 정류소에 있던 버스가 통과함 (다음 차량 번호로 점프) -> 자동 승차 전환
                    confirmBoarded()
                }
                lastBoardingRemaining = boarding
            }

            if !isOnBoardConfirmed,
               let alighting = alightingRealtime,
               let previousAlighting = lastAlightingRemaining,
               alighting < previousAlighting,
               (boardingRealtime ?? lastBoardingRemaining ?? .max) <= 1 {
                confirmBoarded()
            }
        }

        // 2. 승차 완료(탑승 중) 상태에서만 하차 도착 판정 수행
        if isOnBoardConfirmed && !hasArrived {
            if let alighting = alightingRealtime {
                lastAlightingRemaining = alighting
                if alighting == 0 {
                    hasArrived = true
                    emit(.arrived)
                } else if alighting == 1 {
                    if !didFireAlightSoon {
                        didFireAlightSoon = true
                        emit(.alightSoon)
                    }
                }
            } else if let previous = lastAlightingRemaining, previous == 0 {
                hasArrived = true
                emit(.arrived)
            }
        }
    }

    private func confirmBoarded() {
        guard !isOnBoardConfirmed else { return }
        isOnBoardConfirmed = true
        emit(.boarded)
        AppLog.log("auto boarded")
    }

    private func emit(_ event: RidePhaseEvent) {
        pendingEvent = event
    }

    private static func cityCode(for station: GbisStation) -> Int? {
        guard let region = station.regionName else { return nil }
        if region.contains("안양") { return 31040 }
        if region.contains("의왕") { return 31170 }
        if region.contains("군포") { return 31160 }
        return nil
    }

    func startPolling(
        intervalSeconds: TimeInterval = 15,
        onUpdate: @escaping @MainActor (BusRideSnapshot) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(intervalSeconds))
                    guard let self, !Task.isCancelled else { return }
                    let snapshot = try await self.refreshSnapshot()
                    onUpdate(snapshot)
                    if self.hasArrived {
                        return
                    }
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    onError(error)
                }
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func reset() {
        stopPolling()
        selection = nil
        latestSnapshot = nil
        isOnBoardConfirmed = false
        hasArrived = false
        lastBoardingRemaining = nil
        lastAlightingRemaining = nil
        didFireBoardingSoon = false
        didFireAlightSoon = false
        pendingEvent = nil
    }
}
