import Foundation

struct RideSessionRecord: Codable, Sendable {
    var selection: GbisRideSelection
    var snapshot: BusRideSnapshot
    var routeStations: [GbisRouteStation]
    var isOnBoardConfirmed: Bool
    var hasArrived: Bool
    var lastBoardingRemaining: Int?
    var lastAlightingRemaining: Int?
    var didFireBoardingSoon: Bool
    var didFireAlightSoon: Bool
}

/// Persists the in-progress ride so the app can rehydrate after process death.
/// Live Activity survives termination; in-memory ViewModel / tracker do not.
@MainActor
final class RideSessionStore {
    static let shared = RideSessionStore()

    private let defaults = UserDefaults.standard
    private let key = "busisland.ride.session"

    private init() {}

    func load() -> RideSessionRecord? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RideSessionRecord.self, from: data)
    }

    func save(_ record: RideSessionRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
