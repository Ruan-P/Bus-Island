import Foundation

/// Tracks a selected GBIS ride and produces `BusRideSnapshot` updates for Live Activity.
@MainActor
public final class GbisRideTracker {
    private let client: GbisAPIClient
    private var pollTask: Task<Void, Never>?

    public private(set) var selection: GbisRideSelection?
    public private(set) var latestSnapshot: BusRideSnapshot?

    public init(client: GbisAPIClient = .shared) {
        self.client = client
    }

    public var isTracking: Bool { pollTask != nil }

    public func makeInitialSnapshot(from selection: GbisRideSelection) async throws -> BusRideSnapshot {
        self.selection = selection
        let remaining = try await client.remainingStops(
            routeId: selection.route.routeId,
            stationId: selection.destination.stationId,
            destinationSeq: selection.destination.stationSeq
        )
        let snapshot = BusRideSnapshot(
            id: selection.rideID,
            routeNumber: selection.route.routeName,
            destination: selection.destination.stationName,
            remainingStops: remaining
        )
        latestSnapshot = snapshot
        return snapshot
    }

    public func refreshSnapshot() async throws -> BusRideSnapshot {
        guard let selection else {
            throw GbisAPIError.emptyResult
        }
        let remaining = try await client.remainingStops(
            routeId: selection.route.routeId,
            stationId: selection.destination.stationId,
            destinationSeq: selection.destination.stationSeq
        )
        let snapshot = BusRideSnapshot(
            id: selection.rideID,
            routeNumber: selection.route.routeName,
            destination: selection.destination.stationName,
            remainingStops: remaining
        )
        latestSnapshot = snapshot
        return snapshot
    }

    public func startPolling(
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

    public func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    public func reset() {
        stopPolling()
        selection = nil
        latestSnapshot = nil
    }
}
