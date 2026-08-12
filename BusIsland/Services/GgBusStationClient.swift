import CoreLocation
import Foundation

/// 경기데이터드림 OpenAPI — 버스정류소 현황
/// https://openapi.gg.go.kr/BusStation
/// STATION_ID matches GBIS stationId used by busarrivalservice/v2.
public actor GgBusStationClient {
    public static let shared = GgBusStationClient()

    public static let bakedKey = "e770793d363246e0b7d4fe05be175ff6"

    private let baseURL = URL(string: "https://openapi.gg.go.kr/BusStation")!
    private let session: URLSession
    private let apiKey: String

    /// Cache stations for nearby SIGUN codes (Anyang + Uiwang + Gunpo).
    private var cache: [GbisStation] = []
    private var cacheLoadedAt: Date?

    private let nearbySigunCodes = [
        "41170", // 안양시
        "41430", // 의왕시
        "41410", // 군포시
    ]

    public init(session: URLSession = .shared, apiKey: String = GgBusStationClient.bakedKey) {
        self.session = session
        self.apiKey = apiKey
    }

    // MARK: - Public

    public func searchStations(keyword: String) async throws -> [GbisStation] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // API has no free-text filter that works reliably; load local cache and filter.
        let all = try await loadNearbyRegionStations()
        let lower = trimmed.lowercased()
        return all.filter {
            $0.stationName.localizedCaseInsensitiveContains(trimmed)
                || ($0.mobileNo?.contains(trimmed) ?? false)
                || ($0.regionName?.localizedCaseInsensitiveContains(lower) ?? false)
        }
        .prefix(50)
        .map { $0 }
    }

    public func nearbyStations(
        longitude: Double,
        latitude: Double,
        radiusMeters: Int = 800
    ) async throws -> [GbisStation] {
        let user = CLLocation(latitude: latitude, longitude: longitude)
        let all = try await loadNearbyRegionStations()

        var result: [GbisStation] = []
        result.reserveCapacity(40)

        for station in all {
            guard let coord = station.coordinate else { continue }
            let meters = Int(
                user.distance(
                    from: CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                )
            )
            guard meters <= radiusMeters else { continue }
            result.append(
                GbisStation(
                    stationId: station.stationId,
                    stationName: station.stationName,
                    mobileNo: station.mobileNo,
                    regionName: station.regionName,
                    longitude: station.longitude,
                    latitude: station.latitude,
                    distanceMeters: meters
                )
            )
        }

        result.sort { ($0.distanceMeters ?? .max) < ($1.distanceMeters ?? .max) }
        if result.isEmpty {
            throw GbisAPIError.emptyResult
        }
        return Array(result.prefix(40))
    }

    // MARK: - Cache / fetch

    private func loadNearbyRegionStations() async throws -> [GbisStation] {
        if let cacheLoadedAt, Date().timeIntervalSince(cacheLoadedAt) < 3600, !cache.isEmpty {
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

    private func fetchAllPages(sigunCode: String) async throws -> [GgBusStationRow] {
        var page = 1
        let pageSize = 1000
        var all: [GgBusStationRow] = []
        var total = Int.max

        while all.count < total {
            let envelope = try await fetchPage(sigunCode: sigunCode, page: page, size: pageSize)
            total = envelope.totalCount
            let rows = envelope.rows
            if rows.isEmpty { break }
            all.append(contentsOf: rows)
            if rows.count < pageSize { break }
            page += 1
            if page > 20 { break }
        }
        return all
    }

    private func fetchPage(sigunCode: String, page: Int, size: Int) async throws -> GgBusStationEnvelope {
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
            let body = String(data: data, encoding: .utf8)
            throw GbisAPIError.httpStatus(http.statusCode, body)
        }

        do {
            return try JSONDecoder().decode(GgBusStationEnvelope.self, from: data)
        } catch {
            throw GbisAPIError.decodingFailed
        }
    }
}

// MARK: - DTOs

private struct GgBusStationEnvelope: Decodable {
    let BusStation: [GgBusStationBlock]?

    var totalCount: Int {
        for block in BusStation ?? [] {
            if let heads = block.head {
                for head in heads {
                    if let count = head.list_total_count {
                        return count
                    }
                }
            }
        }
        return 0
    }

    var rows: [GgBusStationRow] {
        for block in BusStation ?? [] {
            if let rows = block.row, !rows.isEmpty {
                return rows
            }
        }
        return []
    }
}

private struct GgBusStationBlock: Decodable {
    let head: [GgBusStationHead]?
    let row: [GgBusStationRow]?
}

private struct GgBusStationHead: Decodable {
    let list_total_count: Int?
    let RESULT: GgBusStationResult?
    let api_version: String?
}

private struct GgBusStationResult: Decodable {
    let CODE: String?
    let MESSAGE: String?
}

private struct GgBusStationRow: Decodable {
    let SIGUN_NM: String?
    let SIGUN_CD: String?
    let STATION_NM_INFO: String?
    let STATION_ID: LosslessStringCodable?
    let STATION_MANAGE_NO: LosslessStringCodable?
    let STATION_DIV_NM: String?
    let JURISD_INST_NM: String?
    let LOCPLC_LOC: String?
    let WGS84_LOGT: LosslessStringCodable?
    let WGS84_LAT: LosslessStringCodable?

    func toDomain() -> GbisStation? {
        guard let id = STATION_ID?.value, !id.isEmpty,
              let name = STATION_NM_INFO?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
        else { return nil }

        let lon = Double(WGS84_LOGT?.value ?? "")
        let lat = Double(WGS84_LAT?.value ?? "")
        return GbisStation(
            stationId: id,
            stationName: name,
            mobileNo: STATION_MANAGE_NO?.value,
            regionName: SIGUN_NM,
            longitude: lon,
            latitude: lat,
            distanceMeters: nil
        )
    }
}
