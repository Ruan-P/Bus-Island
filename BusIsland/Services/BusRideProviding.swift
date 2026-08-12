import Foundation

// Design decision: abstraction boundary for swapping in the Seoul Bus API later.
public protocol BusRideProviding: AnyObject, Sendable {
    func currentRide() async -> BusRideSnapshot
    func decrementRemainingStops() async -> BusRideSnapshot
    func resetToPrototype() async -> BusRideSnapshot
}
