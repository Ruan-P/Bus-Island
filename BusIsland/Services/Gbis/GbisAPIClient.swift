import Foundation

public enum GbisAPIError: Error, LocalizedError, Sendable {
    case missingServiceKey
    case invalidURL
    case httpStatus(Int)
    case apiMessage(String)
    case decodingFailed
    case emptyResult

    public var errorDescription: String? {
        switch self {
        case .missingServiceKey:
            return "공공데이터포털 인증키가 없습니다. 설정에서 키를 저장하세요."
        case .invalidURL:
            return "API 요청 URL을 만들 수 없습니다."
        case .httpStatus(let code):
            return "GBIS HTTP 오류 (\(code))"
        case .apiMessage(let message):
            return message
        case .decodingFailed:
            return "GBIS 응답을 해석하지 못했습니다."
        case .emptyResult:
            return "검색 결과가 없습니다."
        }
    }
}

/// GBIS (경기도 버스) OpenAPI client — data.go.kr org 6410000, v2 endpoints.
public actor GbisAPIClient {
    public static let shared = GbisAPIClient()

    private let baseURL = URL(string: "https://apis.data.go.kr/6410000")!
    private let session: URLSession
    private let keyStore: APIKeyStore

    public init(session: URLSession = .shared, keyStore: APIKeyStore = .shared) {
        self.session = session
        self.keyStore = keyStore
    }

    // MARK: - Public API

    public func searchStations(keyword: String) async throws -> [GbisStation] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let body: GbisStationListBody = try await get(
            path: "busstationservice/v2/getBusStationListv2",
            query: ["keyword": trimmed]
        )
        return body.stations.compactMap { $0.toDomain() }
    }

    /// Nearby stations by WGS84 GPS. `x` = longitude, `y` = latitude.
    public func nearbyStations(longitude: Double, latitude: Double) async throws -> [GbisStation] {
        let query = [
            "x": String(longitude),
            "y": String(latitude),
        ]

        // Prefer v2 path used by other station ops; fall back to alternate documented path.
        let paths = [
            "busstationservice/v2/getBusStationAroundListv2",
            "busstationservicev2/getBusStationAroundListv2",
            "busstationservice/getBusStationAroundList",
        ]

        var lastError: Error = GbisAPIError.emptyResult
        for path in paths {
            do {
                let body: GbisStationListBody = try await get(path: path, query: query)
                let stations = body.stations.compactMap { $0.toDomain() }
                if !stations.isEmpty {
                    return stations.sorted {
                        ($0.distanceMeters ?? Int.max) < ($1.distanceMeters ?? Int.max)
                    }
                }
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    public func routes(at stationId: String) async throws -> [GbisRoute] {
        let body: GbisViaRouteListBody = try await get(
            path: "busstationservice/v2/getBusStationViaRouteListv2",
            query: ["stationId": stationId]
        )
        return body.busRouteList?.items.compactMap { $0.toDomain() } ?? []
    }

    public func stations(on routeId: String) async throws -> [GbisRouteStation] {
        let body: GbisRouteStationListBody = try await get(
            path: "busrouteservice/v2/getBusRouteStationListv2",
            query: ["routeId": routeId]
        )
        let list = body.busRouteStationList?.items.compactMap { $0.toDomain() } ?? []
        return list.sorted { $0.stationSeq < $1.stationSeq }
    }

    /// Remaining stops for the nearest bus approaching `stationId` on `routeId`.
    public func remainingStops(routeId: String, stationId: String, destinationSeq: Int) async throws -> Int {
        if let arrivalBased = try? await arrivalRemainingStops(routeId: routeId, stationId: stationId) {
            return max(0, arrivalBased)
        }
        return try await locationRemainingStops(routeId: routeId, destinationSeq: destinationSeq)
    }

    // MARK: - Private

    private func arrivalRemainingStops(routeId: String, stationId: String) async throws -> Int {
        let body: GbisArrivalItemBody = try await get(
            path: "busarrivalservice/v2/getBusArrivalItemv2",
            query: [
                "stationId": stationId,
                "routeId": routeId,
            ]
        )

        if let item = body.busArrivalItem, let stops = item.remainingStops {
            return max(0, stops)
        }
        if let first = body.busArrivalList?.items.first, let stops = first.remainingStops {
            return max(0, stops)
        }
        throw GbisAPIError.emptyResult
    }

    private func locationRemainingStops(routeId: String, destinationSeq: Int) async throws -> Int {
        let body: GbisLocationListBody = try await get(
            path: "buslocationservice/v2/getBusLocationListv2",
            query: ["routeId": routeId]
        )
        let buses = body.busLocationList?.items.compactMap(\.seq) ?? []
        let approaching = buses.filter { $0 <= destinationSeq }
        guard let closest = approaching.max() else {
            throw GbisAPIError.emptyResult
        }
        return max(0, destinationSeq - closest)
    }

    private func get<Body: Decodable>(path: String, query: [String: String]) async throws -> Body {
        guard let serviceKey = keyStore.serviceKey, !serviceKey.isEmpty else {
            throw GbisAPIError.missingServiceKey
        }

        // Use appending(path:) so nested segments like "service/v2/op" are not percent-encoded.
        guard var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        ) else {
            throw GbisAPIError.invalidURL
        }

        var items = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "serviceKey", value: serviceKey))
        items.append(URLQueryItem(name: "format", value: "json"))
        components.queryItems = items

        guard let url = components.url else {
            throw GbisAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GbisAPIError.httpStatus(http.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            let envelope = try decoder.decode(GbisEnvelope<Body>.self, from: data)
            if let header = envelope.response.msgHeader, !header.isSuccess {
                throw GbisAPIError.apiMessage(header.resultMessage ?? "GBIS API 오류")
            }
            guard let body = envelope.response.msgBody else {
                throw GbisAPIError.emptyResult
            }
            return body
        } catch let error as GbisAPIError {
            throw error
        } catch {
            throw GbisAPIError.decodingFailed
        }
    }
}
