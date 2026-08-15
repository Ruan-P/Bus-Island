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
            return "위치 권한이 거부되었습니다. iPhone 설정 > BusIsland > 위치에서 허용해 주세요."
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
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var isRideLocationActive = false

    public override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.delegate = self
    }

    public var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    public var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    /// Ensures when-in-use permission is granted (shows system prompt if needed).
    @discardableResult
    public func ensureWhenInUseAuthorization() async throws -> CLAuthorizationStatus {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return status
        case .denied:
            throw LocationServiceError.denied
        case .restricted:
            throw LocationServiceError.restricted
        case .notDetermined:
            break
        @unknown default:
            break
        }

        return await withCheckedContinuation { continuation in
            self.authContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    public var cachedLocation: CLLocation? {
        if let loc = manager.location, Date().timeIntervalSince(loc.timestamp) < 120 {
            return loc
        }
        return nil
    }

    /// One-shot current location with fast cached-location shortcut. Waits for permission first.
    public func currentLocation(timeoutSeconds: TimeInterval = 8, allowCached: Bool = true) async throws -> CLLocation {
        let status = try await ensureWhenInUseAuthorization()
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .denied:
            throw LocationServiceError.denied
        case .restricted:
            throw LocationServiceError.restricted
        default:
            throw LocationServiceError.unavailable
        }

        // 1. 캐시된 유효 위치(2분 이내)가 있으면 즉시 반환 (0ms)
        if allowCached, let recent = cachedLocation {
            AppLog.log("LocationService: using recent cached location (\(String(format: "%.1f", Date().timeIntervalSince(recent.timestamp)))s old)")
            return recent
        }

        if locationContinuation != nil {
            locationContinuation?.resume(throwing: LocationServiceError.unavailable)
            locationContinuation = nil
        }

        // 2. 빠른 위치 수신을 위해 HundredMeters 설정으로 요청
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation()

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeoutSeconds))
                if let pending = self.locationContinuation {
                    self.locationContinuation = nil
                    // 타임아웃 시 이전 위치라도 있으면 반환
                    if let fallback = self.manager.location {
                        AppLog.log("LocationService: timed out fresh fix, using fallback manager location")
                        pending.resume(returning: fallback)
                    } else {
                        pending.resume(throwing: LocationServiceError.timedOut)
                    }
                }
            }
        }
    }

    /// Keeps the process alive in background while a Live Activity ride is running.
    func startRideBackgroundUpdates() async {
        _ = try? await ensureWhenInUseAuthorization()
        if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }

        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 80
        isRideLocationActive = true
        manager.startUpdatingLocation()
        AppLog.log("ride background location on status=\(manager.authorizationStatus.rawValue)")
    }

    func stopRideBackgroundUpdates() {
        guard isRideLocationActive else { return }
        isRideLocationActive = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        manager.pausesLocationUpdatesAutomatically = true
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = kCLDistanceFilterNone
        AppLog.log("ride background location off")
    }
}

extension LocationService: CLLocationManagerDelegate {
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            // Only resume when user has responded (not still notDetermined).
            guard status != .notDetermined else { return }
            if let authContinuation {
                self.authContinuation = nil
                authContinuation.resume(returning: status)
            }
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            guard let locationContinuation else { return }
            self.locationContinuation = nil
            locationContinuation.resume(returning: location)
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard let locationContinuation else { return }
            self.locationContinuation = nil
            locationContinuation.resume(throwing: LocationServiceError.underlying(error.localizedDescription))
        }
    }
}
