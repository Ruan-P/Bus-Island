import Foundation

@MainActor
public final class MockBusRideService: BusRideProviding {
    private var snapshot: BusRideSnapshot

    public init(snapshot: BusRideSnapshot = .prototype) {
        self.snapshot = snapshot
    }

    public func currentRide() async -> BusRideSnapshot {
        snapshot
    }

    public func decrementRemainingStops() async -> BusRideSnapshot {
        let next = max(0, snapshot.remainingStops - 1)
        snapshot = .init(
            id: snapshot.id,
            routeNumber: snapshot.routeNumber,
            destination: snapshot.destination,
            remainingStops: next
        )
        return snapshot
    }

    public func resetToPrototype() async -> BusRideSnapshot {
        snapshot = .prototype
        return snapshot
    }
}
