import CoreLocation
import Foundation

public enum GbisAPIError: Error, LocalizedError, Sendable {
    case missingServiceKey
    case invalidURL
    case httpStatus(Int, String?)
    case apiMessage(String)
    case decodingFailed
    case emptyResult
    case stationServiceUnavailable

    public var errorDescription: String? {
        switch self {
        case .missingServiceKey:
            return "공공데이터포털 인증키가 없습니다."
        case .invalidURL:
            return "API 요청 URL을 만들 수 없습니다."
        case .httpStatus(let code, let body):
            if let body, !body.isEmpty {
                return "GBIS HTTP \(code): \(body.prefix(160))"
            }
            return "GBIS HTTP 오류 (\(code))"
        case .apiMessage(let message):
            return message
        case .decodingFailed:
            return "GBIS 응답을 해석하지 못했습니다."
        case .emptyResult:
            return "검색 결과가 없습니다."
        case .stationServiceUnavailable:
            return "이 키에는 정류소 조회 API 권한이 없습니다. 노선 번호로 검색하세요."
        }
    }
}

/// GBIS client using only APIs available on the baked personal key:
/// - busrouteservice/v2 (route list, route stations w/ coords)
/// - busarrivalservice/v2 (remaining stops)
///
/// busstationservice / buslocationservice return 403 for this key.
public actor GbisAPIClient {
    public static let shared = GbisAPIClient()

    private let baseURL = URL(string: "https://apis.data.go.kr/6410000")!
    private let session: URLSession
    private let keyStore: APIKeyStore

    /// Anyang/Uiwang area seed routes for GPS nearby (no station-around API).
    private let nearbySeedKeywords = [
        "1-1", "1-2", "2", "3", "5", "6", "8", "8-1", "8-2",
        "9", "10", "11", "11-1", "11-2", "11-3", "11-5", "11-6",
        "12", "15", "15-1", "15-2", "20", "31", "31-7", "32",
        "51", "52", "55", "60", "62", "65", "70", "80",
        "333", "441", "542", "5531", "5623", "5-1", "6-1",
    ]

    public init(session: URLSession = .shared, keyStore: APIKeyStore = .shared) {
        self.session = session
        self.keyStore = keyStore
    }

    // MARK: - Public

    public func searchRoutes(keyword: String) async throws -> [GbisRoute] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let body: GbisViaRouteListBody = try await get(
            path: "busrouteservice/v2/getBusRouteListv2",
            query: ["keyword": trimmed]
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

    /// Nearby stations via route-station coords (works without busstationservice permission).
    public func nearbyStations(longitude: Double, latitude: Double) async throws -> [GbisStation] {
        let user = CLLocation(latitude: latitude, longitude: longitude)
        var best: [String: GbisStation] = [:]

        for keyword in nearbySeedKeywords {
            let routes: [GbisRoute]
            do {
                routes = try await searchRoutes(keyword: keyword)
            } catch {
                continue
            }

            // Prefer routes mentioning 안양/의왕/군포 in region, else first few.
            let preferred = routes.filter {
                let region = $0.regionName ?? ""
                return region.contains("안양") || region.contains("의왕") || region.contains("군포")
            }
            let candidates = (preferred.isEmpty ? Array(routes.prefix(2)) : Array(preferred.prefix(2)))

            for route in candidates {
                let stops: [GbisRouteStation]
                do {
                    stops = try await stations(on: route.routeId)
                } catch {
                    continue
                }
                for stop in stops {
                    guard let coord = stop.coordinate else { continue }
                    let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let meters = Int(user.distance(from: loc))
                    guard meters <= 900 else { continue }

                    let station = GbisStation(
                        stationId: stop.stationId,
                        stationName: stop.stationName,
                        mobileNo: stop.mobileNo,
                        regionName: route.routeName,
                        longitude: coord.longitude,
                        latitude: coord.latitude,
                        distanceMeters: meters
                    )
                    if let existing = best[stop.stationId] {
                        if (station.distanceMeters ?? .max) < (existing.distanceMeters ?? .max) {
                            best[stop.stationId] = station
                        }
                    } else {
                        best[stop.stationId] = station
                    }
                }
            }
        }

        let result = best.values.sorted { ($0.distanceMeters ?? .max) < ($1.distanceMeters ?? .max) }
        if result.isEmpty {
            throw GbisAPIError.emptyResult
        }
        return Array(result.prefix(30))
    }

    /// Routes serving a station — derived from arrival list (no station-via-route API needed).
    public func routes(at stationId: String) async throws -> [GbisRoute] {
        let body: GbisArrivalItemBody = try await get(
            path: "busarrivalservice/v2/getBusArrivalListv2",
            query: ["stationId": stationId]
        )
        let items = body.busArrivalList?.items ?? []
        var seen = Set<String>()
        var routes: [GbisRoute] = []
        for item in items {
            guard let routeId = item.routeId?.value, !routeId.isEmpty,
                  let routeName = item.routeName, !routeName.isEmpty,
                  seen.insert(routeId).inserted
            else { continue }
            routes.append(
                GbisRoute(
                    routeId: routeId,
                    routeName: routeName,
                    routeTypeName: nil,
                    regionName: item.routeDestName
                )
            )
        }
        if routes.isEmpty {
            throw GbisAPIError.emptyResult
        }
        return routes
    }

    public func remainingStops(routeId: String, stationId: String, destinationSeq: Int) async throws -> Int {
        // Prefer arrival item (destination station + route).
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
            // fall through
        }

        // Fallback: arrival list filtered by routeId
        let listBody: GbisArrivalItemBody = try await get(
            path: "busarrivalservice/v2/getBusArrivalListv2",
            query: ["stationId": stationId]
        )
        if let match = listBody.busArrivalList?.items.first(where: { $0.routeId?.value == routeId }),
           let stops = match.remainingStops {
            return max(0, stops)
        }

        // Last resort: estimate from boarding seq if we only know destinationSeq (not ideal)
        _ = destinationSeq
        throw GbisAPIError.emptyResult
    }

    // MARK: - HTTP

    private func get<Body: Decodable>(path: String, query: [String: String]) async throws -> Body {
        guard let serviceKey = keyStore.serviceKey, !serviceKey.isEmpty else {
            throw GbisAPIError.missingServiceKey
        }

        // data.go.kr expects Encoding key in query. If we have Decoding key, encode once.
        // If key already contains %, treat as Encoding key and append as-is.
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

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 25

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let snippet = String(data: data, encoding: .utf8)
            if http.statusCode == 403, path.contains("busstationservice") {
                throw GbisAPIError.stationServiceUnavailable
            }
            throw GbisAPIError.httpStatus(http.statusCode, snippet)
        }

        if let text = String(data: data, encoding: .utf8),
           text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
            throw GbisAPIError.apiMessage("XML 응답 — JSON format 미지원 또는 권한 문제")
        }

        do {
            let envelope = try JSONDecoder().decode(GbisEnvelope<Body>.self, from: data)
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
