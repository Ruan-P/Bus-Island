import Foundation

enum GbisAPIError: Error, LocalizedError, Sendable {
    case missingServiceKey
    case invalidURL
    case httpStatus(Int, String?)
    case apiMessage(String)
    case decodingFailed
    case emptyResult
    case stationServiceUnavailable

    var errorDescription: String? {
        switch self {
        case .missingServiceKey:
            return "공공데이터포털 인증키가 없습니다."
        case .invalidURL:
            return "API 요청 URL을 만들 수 없습니다."
        case .httpStatus(let code, let body):
            if code == 403 {
                return "공공데이터포털 인증 실패 (HTTP 403). 키가 해당 서비스에 등록됐는지 확인하세요."
            }
            if code >= 500 {
                return "버스 정보 서버 일시적 장애 (HTTP \(code)). 잠시 후 다시 시도해 주세요."
            }
            if let body, !body.isEmpty {
                let snippet = body.count > 160 ? String(body.prefix(160)) : body
                return "GBIS HTTP \(code): \(snippet)"
            }
            return "GBIS HTTP 오류 (\(code))"
        case .apiMessage(let message):
            return message
        case .decodingFailed:
            return "GBIS 응답을 해석하지 못했습니다."
        case .emptyResult:
            return "검색 결과가 없습니다."
        case .stationServiceUnavailable:
            return "정류소 API 권한이 없습니다. 노선 번호로 검색하세요."
        }
    }
}

/// GBIS realtime (data.go.kr 6410000) + TAGO stations/arrival fallback (1613000).
actor GbisAPIClient {
    static let shared = GbisAPIClient()

    private let baseURL = URL(string: "https://apis.data.go.kr/6410000")!
    private let session: URLSession
    private let keyStore: APIKeyStore
    private let stationCatalog: TagoStationClient
    private let tagoArrival: TagoArrivalClient

    init(session: URLSession = .shared, keyStore: APIKeyStore? = nil) {
        self.session = session
        self.keyStore = keyStore ?? APIKeyStore.shared
        self.stationCatalog = TagoStationClient.shared
        self.tagoArrival = TagoArrivalClient.shared
    }

    // MARK: - Routes / stations on route

    func searchRoutes(keyword: String) async throws -> [GbisRoute] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let body: GbisViaRouteListBody = try await get(
            path: "busrouteservice/v2/getBusRouteListv2",
            query: ["keyword": trimmed]
        )
        return body.busRouteList?.items.compactMap { $0.toDomain() } ?? []
    }

    func stations(on routeId: String) async throws -> [GbisRouteStation] {
        let body: GbisRouteStationListBody = try await get(
            path: "busrouteservice/v2/getBusRouteStationListv2",
            query: ["routeId": routeId]
        )
        let list = body.busRouteStationList?.items.compactMap { $0.toDomain() } ?? []
        return list.sorted { $0.stationSeq < $1.stationSeq }
    }

    // MARK: - Nearby / name (GBIS around + TAGO fallback)

    func nearbyStations(longitude: Double, latitude: Double) async throws -> [GbisStation] {
        // 1. GBIS Around list query (Fast direct coordinate lookup)
        do {
            let body: GbisStationAroundListBody = try await get(
                path: "busstationservice/v2/getBusStationAroundListv2",
                query: [
                    "x": String(format: "%.6f", longitude),
                    "y": String(format: "%.6f", latitude),
                ]
            )
            let items = body.busStationAroundList?.items.compactMap { $0.toDomain() } ?? []
            if !items.isEmpty {
                AppLog.log("GBIS nearby hit: \(items.count) stations")
                return items.sorted { ($0.distanceMeters ?? Int.max) < ($1.distanceMeters ?? Int.max) }
            }
        } catch {
            AppLog.log("GBIS around list query failed: \(error.localizedDescription)")
        }

        // 2. TAGO parallel station catalog lookup
        return try await stationCatalog.nearbyStations(longitude: longitude, latitude: latitude)
    }

    func searchStationsByName(keyword: String) async throws -> [GbisStation] {
        try await stationCatalog.searchStations(keyword: keyword)
    }

    /// Routes currently arriving at a station (arrival list).
    func routes(at stationId: String) async throws -> [GbisRoute] {
        AppLog.log("routes(at:) stationId=\(stationId)")
        do {
            let body: GbisArrivalItemBody = try await get(
                path: "busarrivalservice/v2/getBusArrivalListv2",
                query: ["stationId": stationId]
            )
            let items = body.busArrivalList?.items ?? []
            var seen = Set<String>()
            var routes: [GbisRoute] = []
            for item in items {
                guard let routeId = item.routeId?.value, !routeId.isEmpty,
                      seen.insert(routeId).inserted
                else { continue }
                
                let name = item.routeName?.value
                let dest = item.routeDestName?.value
                let displayName = (name != nil && !name!.isEmpty) ? name! : (dest != nil && !dest!.isEmpty ? dest! : "노선 \(routeId)")
                
                routes.append(
                    GbisRoute(
                        routeId: routeId,
                        routeName: displayName,
                        routeTypeName: nil,
                        regionName: dest
                    )
                )
            }
            AppLog.log("routes(at:) parsed=\(routes.count) rawItems=\(items.count)")
            return routes
        } catch {
            AppLog.log("routes(at:) arrival query failed: \(error.localizedDescription)")
            return []
        }
    }

    func remainingStops(
        routeId: String,
        stationId: String,
        cityCode: Int? = nil
    ) async -> Int? {
        do {
            let body: GbisArrivalItemBody = try await get(
                path: "busarrivalservice/v2/getBusArrivalItemv2",
                query: [
                    "stationId": stationId,
                    "routeId": routeId,
                ]
            )
            if let stops = body.busArrivalItem?.remainingStops {
                return max(0, stops)
            }
            if let stops = body.busArrivalList?.items.first?.remainingStops {
                return max(0, stops)
            }
        } catch {
            AppLog.log("GBIS arrival item fail: \(error.localizedDescription)")
        }

        do {
            let listBody: GbisArrivalItemBody = try await get(
                path: "busarrivalservice/v2/getBusArrivalListv2",
                query: ["stationId": stationId]
            )
            if let match = listBody.busArrivalList?.items.first(where: { $0.routeId?.value == routeId }),
               let stops = match.remainingStops {
                return max(0, stops)
            }
        } catch {
            AppLog.log("GBIS arrival list fail: \(error.localizedDescription)")
        }

        if let stops = try? await tagoArrival.remainingStops(
            stationId: stationId,
            routeId: routeId,
            cityCode: cityCode
        ) {
            return stops
        }

        return nil
    }

    // MARK: - HTTP (data.go.kr)

    private func get<Body: Decodable>(path: String, query: [String: String]) async throws -> Body {
        guard let serviceKey = keyStore.serviceKey, !serviceKey.isEmpty else {
            throw GbisAPIError.missingServiceKey
        }

        let keyQueryValue: String
        if serviceKey.contains("%") {
            keyQueryValue = serviceKey
        } else {
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            keyQueryValue = serviceKey.addingPercentEncoding(withAllowedCharacters: allowed) ?? serviceKey
        }

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")

        var pairs: [String] = []
        for (name, value) in query.sorted(by: { $0.key < $1.key }) {
            let n = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            pairs.append("\(n)=\(v)")
        }
        pairs.append("serviceKey=\(keyQueryValue)")
        pairs.append("format=json")

        let urlString = baseURL.appending(path: path).absoluteString + "?" + pairs.joined(separator: "&")
        guard let url = URL(string: urlString) else {
            throw GbisAPIError.invalidURL
        }
        AppLog.log("GBIS GET \(path) \(query)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 25

        var attempts = 0
        while attempts < 3 {
            attempts += 1
            do {
                let (data, response) = try await session.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let bodyText = String(data: data, encoding: .utf8)
                AppLog.log("GBIS HTTP \(status) \(path) \(AppLog.snippet(bodyText))")
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    if http.statusCode >= 500 && attempts < 3 {
                        try? await Task.sleep(for: .milliseconds(800))
                        continue
                    }
                    throw GbisAPIError.httpStatus(http.statusCode, bodyText)
                }

                if let text = String(data: data, encoding: .utf8),
                   text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
                    throw GbisAPIError.apiMessage("XML 응답 — JSON format 미지원 또는 권한 문제")
                }

                let envelope = try JSONDecoder().decode(GbisEnvelope<Body>.self, from: data)
                if let header = envelope.response.msgHeader, !header.isSuccess {
                    throw GbisAPIError.apiMessage(header.resultMessage ?? "GBIS API 오류")
                }
                guard let body = envelope.response.msgBody else {
                    throw GbisAPIError.emptyResult
                }
                return body
            } catch let error as GbisAPIError {
                if case .httpStatus(let code, _) = error, code >= 500, attempts < 3 {
                    try? await Task.sleep(for: .milliseconds(800))
                    continue
                }
                throw error
            } catch {
                if attempts < 3 {
                    try? await Task.sleep(for: .milliseconds(800))
                    continue
                }
                throw GbisAPIError.decodingFailed
            }
        }
        throw GbisAPIError.emptyResult
    }
}
