import CoreLocation
import Foundation

/// Seoul City Bus Open API Client (ws.bus.go.kr)
actor SeoulBusAPIClient {
    static let shared = SeoulBusAPIClient()

    private let baseURL = URL(string: "https://ws.bus.go.kr/api/rest")!
    private let session: URLSession
    private let keyStore: APIKeyStore

    private var routeStationsMemoryCache: [String: (savedAt: Date, stations: [GbisRouteStation])] = [:]
    private let routeStationsDiskCacheFileName = "seoul_route_stations_cache_v1.json"

    init(session: URLSession = .shared, keyStore: APIKeyStore? = nil) {
        self.session = session
        self.keyStore = keyStore ?? APIKeyStore.shared
    }

    // MARK: - Search Routes

    func searchRoutes(keyword: String) async throws -> [GbisRoute] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let env: SeoulBusEnvelope<SeoulRouteDTO> = try await get(
            path: "busRouteInfo/getBusRouteList",
            query: ["strSrch": trimmed]
        )
        return env.msgBody?.items.compactMap { $0.toDomain() } ?? []
    }

    // MARK: - Search Stations

    func searchStationsByName(keyword: String) async throws -> [GbisStation] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let env: SeoulBusEnvelope<SeoulStationDTO> = try await get(
            path: "stationinfo/getStationByName",
            query: ["stSrch": trimmed]
        )
        return env.msgBody?.items.compactMap { $0.toDomain() } ?? []
    }

    // MARK: - Nearby Stations (by Position)

    func nearbyStations(longitude: Double, latitude: Double, radiusMeters: Int = 500) async throws -> [GbisStation] {
        let env: SeoulBusEnvelope<SeoulStationDTO> = try await get(
            path: "stationinfo/getStationByPos",
            query: [
                "tmX": String(format: "%.6f", longitude),
                "tmY": String(format: "%.6f", latitude),
                "radius": "\(radiusMeters)"
            ]
        )
        let stations = env.msgBody?.items.compactMap { $0.toDomain() } ?? []
        return stations
    }

    // MARK: - Routes at Station (with Realtime Arrival)

    func routes(at stationId: String, arsId: String? = nil) async throws -> [GbisRoute] {
        // 서울 정류소 ID(stId) 또는 정류소 고유번호(arsId)
        let rawId = stationId.replacingOccurrences(of: "SEL:", with: "")
        let targetArs = (arsId != nil && !arsId!.isEmpty && arsId != "0") ? arsId! : rawId

        let env: SeoulBusEnvelope<SeoulStationRouteDTO> = try await get(
            path: "stationinfo/getRouteByStation",
            query: ["arsId": targetArs]
        )
        let items = env.msgBody?.items ?? []
        return items.compactMap { $0.toDomain() }
    }

    // MARK: - Route Stations (Stations on Route)

    func stations(on routeId: String) async throws -> [GbisRouteStation] {
        let cleanRouteId = routeId.replacingOccurrences(of: "SEL:", with: "")

        if let cached = routeStationsMemoryCache[cleanRouteId],
           Date().timeIntervalSince(cached.savedAt) < 604800,
           !cached.stations.isEmpty {
            return cached.stations
        }

        let env: SeoulBusEnvelope<SeoulRouteStationDTO> = try await get(
            path: "busRouteInfo/getStaionsByRoute",
            query: ["busRouteId": cleanRouteId]
        )
        let list = (env.msgBody?.items.compactMap { $0.toDomain() } ?? [])
            .sorted { $0.stationSeq < $1.stationSeq }

        if !list.isEmpty {
            routeStationsMemoryCache[cleanRouteId] = (Date(), list)
        }
        return list
    }

    // MARK: - Remaining Stops (Realtime Single Route/Station)

    func remainingStops(
        routeId: String,
        stationId: String,
        stationSeq: Int? = nil
    ) async -> (remainingStops: Int?, predictMinutes: Int?) {
        let cleanRouteId = routeId.replacingOccurrences(of: "SEL:", with: "")
        let cleanStationId = stationId.replacingOccurrences(of: "SEL:", with: "")

        var query: [String: String] = [
            "busRouteId": cleanRouteId,
            "stId": cleanStationId
        ]
        if let seq = stationSeq {
            query["ord"] = "\(seq)"
        }

        do {
            let env: SeoulBusEnvelope<SeoulStationRouteDTO> = try await get(
                path: "arrive/getArrInfoByRoute",
                query: query
            )
            guard let item = env.msgBody?.items.first else {
                return (nil, nil)
            }
            return SeoulBusArrivalParser.parse(arrmsg: item.arrmsg1, traTime: item.traTime1)
        } catch {
            AppLog.log("Seoul remainingStops failed: \(error.localizedDescription)")
            return (nil, nil)
        }
    }

    // MARK: - Private HTTP Request helper

    private func get<T: Decodable & Sendable>(
        path: String,
        query: [String: String],
        timeout: TimeInterval = 10
    ) async throws -> T {
        guard let serviceKey = keyStore.serviceKey, !serviceKey.isEmpty else {
            throw GbisAPIError.missingServiceKey
        }

        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true) else {
            throw GbisAPIError.invalidURL
        }

        var items = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "serviceKey", value: serviceKey))
        items.append(URLQueryItem(name: "resultType", value: "json"))
        components.queryItems = items

        guard let url = components.url else {
            throw GbisAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GbisAPIError.httpStatus(-1, "Invalid HTTP response")
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw GbisAPIError.httpStatus(http.statusCode, body)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            let snippet = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            AppLog.log("SeoulBus JSON decode failed: \(error) body: \(snippet)")
            throw GbisAPIError.decodingFailed
        }
    }
}
