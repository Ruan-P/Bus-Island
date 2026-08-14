import Foundation

/// Tracks a selected GBIS ride and produces `BusRideSnapshot` updates for Live Activity.
@MainActor
final class GbisRideTracker {
    private let client: GbisAPIClient
    private var pollTask: Task<Void, Never>?

    private(set) var selection: GbisRideSelection?
    private(set) var latestSnapshot: BusRideSnapshot?
    private(set) var isOnBoardConfirmed: Bool = false

    init(client: GbisAPIClient? = nil) {
        self.client = client ?? GbisAPIClient.shared
    }

    var isTracking: Bool { pollTask != nil }

    func makeInitialSnapshot(from selection: GbisRideSelection) async throws -> BusRideSnapshot {
        self.selection = selection
        self.isOnBoardConfirmed = false
        let city = Self.cityCode(for: selection.boardingStation)
        
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
        let seqDiff = max(1, selection.destination.stationSeq - selection.boardingSeq)

        let boardingStops = boardingRealtime ?? 0
        let alightingStops = alightingRealtime ?? seqDiff

        // If boarding stops is 0, user might already be boarding
        if boardingRealtime != nil && boardingStops == 0 {
            isOnBoardConfirmed = true
        }

        let snapshot = BusRideSnapshot(
            id: selection.rideID,
            routeNumber: selection.route.routeName,
            boarding: selection.boardingStation.stationName,
            destination: selection.destination.stationName,
            boardingRemainingStops: isOnBoardConfirmed ? 0 : boardingStops,
            remainingStops: alightingStops
        )
        latestSnapshot = snapshot
        return snapshot
    }

    func refreshSnapshot() async throws -> BusRideSnapshot {
        guard let selection else {
            throw GbisAPIError.emptyResult
        }
        let city = Self.cityCode(for: selection.boardingStation)

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
        let seqDiff = max(1, selection.destination.stationSeq - selection.boardingSeq)

        if let b = boardingRealtime, b == 0 {
            isOnBoardConfirmed = true
        }

        let boardingStops: Int
        if isOnBoardConfirmed {
            boardingStops = 0
        } else {
            boardingStops = boardingRealtime ?? (latestSnapshot?.boardingRemainingStops ?? 0)
        }

        let alightingStops = alightingRealtime ?? (latestSnapshot?.remainingStops ?? seqDiff)

        let snapshot = BusRideSnapshot(
            id: selection.rideID,
            routeNumber: selection.route.routeName,
            boarding: selection.boardingStation.stationName,
            destination: selection.destination.stationName,
            boardingRemainingStops: boardingStops,
            remainingStops: alightingStops
        )
        latestSnapshot = snapshot
        return snapshot
    }

    func markAsBoarded() -> BusRideSnapshot? {
        guard var current = latestSnapshot else { return nil }
        isOnBoardConfirmed = true
        current.boardingRemainingStops = 0
        latestSnapshot = current
        return current
    }

    /// TAGO cityCode from boarding station region name (안양/의왕/군포, 실측).
    private static func cityCode(for station: GbisStation) -> Int? {
        guard let region = station.regionName else { return nil }
        if region.contains("안양") { return 31040 }
        if region.contains("의왕") { return 31170 }
        if region.contains("군포") { return 31160 }
        return nil
    }

    func startPolling(
        intervalSeconds: TimeInterval = 20,
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
    }
}
