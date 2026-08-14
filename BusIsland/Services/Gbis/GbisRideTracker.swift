import Foundation

/// Tracks a selected GBIS ride and produces `BusRideSnapshot` updates for Live Activity.
@MainActor
final class GbisRideTracker {
    private let client: GbisAPIClient
    private var pollTask: Task<Void, Never>?

    private(set) var selection: GbisRideSelection?
    private(set) var latestSnapshot: BusRideSnapshot?

    init(client: GbisAPIClient? = nil) {
        self.client = client ?? GbisAPIClient.shared
    }

    var isTracking: Bool { pollTask != nil }

    func makeInitialSnapshot(from selection: GbisRideSelection) async throws -> BusRideSnapshot {
        self.selection = selection
        let city = Self.cityCode(for: selection.boardingStation)
        async let boardingLeft = client.remainingStops(
            routeId: selection.route.routeId,
            stationId: selection.boardingStation.stationId,
            destinationSeq: 0,
            cityCode: city
        )
        async let alightingLeft = client.remainingStops(
            routeId: selection.route.routeId,
            stationId: selection.destination.stationId,
            destinationSeq: selection.destination.stationSeq,
            cityCode: city
        )
        let snapshot = try await BusRideSnapshot(
            id: selection.rideID,
            routeNumber: selection.route.routeName,
            boarding: selection.boardingStation.stationName,
            destination: selection.destination.stationName,
            boardingRemainingStops: boardingLeft,
            remainingStops: alightingLeft
        )
        latestSnapshot = snapshot
        return snapshot
    }

    func refreshSnapshot() async throws -> BusRideSnapshot {
        guard let selection else {
            throw GbisAPIError.emptyResult
        }
        let city = Self.cityCode(for: selection.boardingStation)
        async let boardingLeft = client.remainingStops(
            routeId: selection.route.routeId,
            stationId: selection.boardingStation.stationId,
            destinationSeq: 0,
            cityCode: city
        )
        async let alightingLeft = client.remainingStops(
            routeId: selection.route.routeId,
            stationId: selection.destination.stationId,
            destinationSeq: selection.destination.stationSeq,
            cityCode: city
        )
        let snapshot = try await BusRideSnapshot(
            id: selection.rideID,
            routeNumber: selection.route.routeName,
            boarding: selection.boardingStation.stationName,
            destination: selection.destination.stationName,
            boardingRemainingStops: boardingLeft,
            remainingStops: alightingLeft
        )
        latestSnapshot = snapshot
        return snapshot
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
    }
}
