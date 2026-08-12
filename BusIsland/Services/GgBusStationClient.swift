import CoreLocation
import Foundation

/// 경기데이터드림 OpenAPI — 버스정류소 현황
/// https://openapi.gg.go.kr/BusStation
/// STATION_ID matches GBIS stationId used by busarrivalservice/v2.
actor GgBusStationClient {
    static let shared = GgBusStationClient()
    static let bakedKey = "e770793d363246e0b7d4fe05be175ff6"

    private let baseURL = URL(string: "https://openapi.gg.go.kr/BusStation")!
    private let session: URLSession
    private let apiKey: String

    private var cache: [GbisStation] = []
    private var cacheLoadedAt: Date?

    /// 안양 / 의왕 / 군포
    private let nearbySigunCodes = ["41170", "41430", "41410"]

    init(session: URLSession = .shared, apiKey: String = GgBusStationClient.bakedKey) {
        self.session = session
        self.apiKey = apiKey
    }

    func searchStations(keyword: String) async throws -> [GbisStation] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let all = try await loadNearbyRegionStations()
        let filtered = all.filter { station in
            station.stationName.localizedCaseInsensitiveContains(trimmed)
                || (station.mobileNo?.contains(trimmed) ?? false)
                || (station.regionName?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
        return Array(filtered.prefix(50))
    }

    func nearbyStations(
        longitude: Double,
        latitude: Double,
        radiusMeters: Int = 800
    ) async throws -> [GbisStation] {
        let user = CLLocation(latitude: latitude, longitude: longitude)
        let all = try await loadNearbyRegionStations()

        var result: [GbisStation] = []
        for station in all {
            guard let lat = station.latitude, let lon = station.longitude else { continue }
            let meters = Int(
                user.distance(from: CLLocation(latitude: lat, longitude: lon))
            )
            guard meters <= radiusMeters else { continue }
            result.append(
                GbisStation(
                    stationId: station.stationId,
                    stationName: station.stationName,
                    mobileNo: station.mobileNo,
                    regionName: station.regionName,
                    longitude: lon,
                    latitude: lat,
                    distanceMeters: meters
                )
            )
        }

        result.sort { ($0.distanceMeters ?? Int.max) < ($1.distanceMeters ?? Int.max) }
        if result.isEmpty {
            throw GbisAPIError.emptyResult
        }
        return Array(result.prefix(40))
    }

    // MARK: - Private

    private func loadNearbyRegionStations() async throws -> [GbisStation] {
        if let cacheLoadedAt,
           Date().timeIntervalSince(cacheLoadedAt) < 3600,
           !cache.isEmpty {
            return cache
        }

        var merged: [String: GbisStation] = [:]
        for code in nearbySigunCodes {
            let rows = try await fetchAllPages(sigunCode: code)
            for row in rows {
                guard let station = row.toDomain() else { continue }
                merged[station.stationId] = station
            }
        }

        let list = Array(merged.values)
        if list.isEmpty {
            throw GbisAPIError.emptyResult
        }
        cache = list
        cacheLoadedAt = Date()
        return list
    }

    private func fetchAllPages(sigunCode: String) async throws -> [GgStationRow] {
        var page = 1
        let pageSize = 1000
        var all: [GgStationRow] = []
        var total = Int.max

        while all.count < total {
            let pageResult = try await fetchPage(sigunCode: sigunCode, page: page, size: pageSize)
            total = pageResult.total
            if pageResult.rows.isEmpty { break }
            all.append(contentsOf: pageResult.rows)
            if pageResult.rows.count < pageSize { break }
            page += 1
            if page > 20 { break }
        }
        return all
    }

    private func fetchPage(sigunCode: String, page: Int, size: Int) async throws -> (total: Int, rows: [GgStationRow]) {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "KEY", value: apiKey),
            URLQueryItem(name: "Type", value: "json"),
            URLQueryItem(name: "pIndex", value: String(page)),
            URLQueryItem(name: "pSize", value: String(size)),
            URLQueryItem(name: "SIGUN_CD", value: sigunCode),
        ]
        guard let url = components.url else {
            throw GbisAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GbisAPIError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = root["BusStation"] as? [Any]
        else {
            throw GbisAPIError.decodingFailed
        }

        var total = 0
        var rows: [GgStationRow] = []

        for block in blocks {
            guard let dict = block as? [String: Any] else { continue }
            if let head = dict["head"] as? [[String: Any]] {
                for item in head {
                    if let count = item["list_total_count"] as? Int {
                        total = count
                    } else if let count = item["list_total_count"] as? NSNumber {
                        total = count.intValue
                    }
                }
            }
            if let rowArray = dict["row"] as? [[String: Any]] {
                for raw in rowArray {
                    rows.append(GgStationRow(raw: raw))
                }
            }
        }

        return (total, rows)
    }
}

// Manual JSON row — avoids Codable edge cases with mixed number/string fields.
private struct GgStationRow {
    let stationId: String
    let stationName: String
    let mobileNo: String?
    let regionName: String?
    let longitude: Double?
    let latitude: Double?

    init(raw: [String: Any]) {
        func str(_ key: String) -> String? {
            if let s = raw[key] as? String { return s }
            if let n = raw[key] as? NSNumber { return n.stringValue }
            return nil
        }
        func dbl(_ key: String) -> Double? {
            if let n = raw[key] as? NSNumber { return n.doubleValue }
            if let s = raw[key] as? String { return Double(s) }
            return nil
        }

        stationId = str("STATION_ID") ?? ""
        stationName = (str("STATION_NM_INFO") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        mobileNo = str("STATION_MANAGE_NO")
        regionName = str("SIGUN_NM")
        longitude = dbl("WGS84_LOGT")
        latitude = dbl("WGS84_LAT")
    }

    func toDomain() -> GbisStation? {
        guard !stationId.isEmpty, !stationName.isEmpty else { return nil }
        return GbisStation(
            stationId: stationId,
            stationName: stationName,
            mobileNo: mobileNo,
            regionName: regionName,
            longitude: longitude,
            latitude: latitude,
            distanceMeters: nil
        )
    }
}
