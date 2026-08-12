import CoreLocation
import Foundation

public enum LocationServiceError: Error, LocalizedError, Sendable {
    case denied
    case restricted
    case unavailable
    case timedOut
    case underlying(String)

    public var errorDescription: String? {
        switch self {
        case .denied:
            return "위치 권한이 거부되었습니다. 설정 > BusIsland에서 허용해 주세요."
        case .restricted:
            return "위치 서비스를 사용할 수 없습니다."
        case .unavailable:
            return "현재 위치를 가져올 수 없습니다."
        case .timedOut:
            return "위치 확인 시간이 초과되었습니다."
        case .underlying(let message):
            return message
        }
    }
}

@MainActor
public final class LocationService: NSObject {
    public static let shared = LocationService()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    public override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.delegate = self
    }

    public var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    public func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// One-shot current location.
    public func currentLocation(timeoutSeconds: TimeInterval = 12) async throws -> CLLocation {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied:
            throw LocationServiceError.denied
        case .restricted:
            throw LocationServiceError.restricted
        default:
            break
        }

        if continuation != nil {
            continuation?.resume(throwing: LocationServiceError.unavailable)
            continuation = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeoutSeconds))
                if let pending = self.continuation {
                    self.continuation = nil
                    pending.resume(throwing: LocationServiceError.timedOut)
                }
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // No-op; next requestLocation will use updated status.
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            guard let continuation else { return }
            self.continuation = nil
            continuation.resume(returning: location)
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard let continuation else { return }
            self.continuation = nil
            continuation.resume(throwing: LocationServiceError.underlying(error.localizedDescription))
        }
    }
}
