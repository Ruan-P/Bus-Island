import CoreLocation
import Foundation

/// TAGO (국토교통부) 버스정류소정보 — 정류소 목록/검색/근처 조회
/// https://apis.data.go.kr/1613000/BusSttnInfoInqireService
///
/// nodeId 규칙 (실측): `nodeId = "GGB" + GBIS stationId`
actor TagoStationClient {
    static let shared = TagoStationClient()

    private let baseURL = URL(string: "https://apis.data.go.kr/1613000/BusSttnInfoInqireService")!
    private let session: URLSession
    private let keyStore: APIKeyStore

    /// getCtyCodeList 실측 (2026-08-13).
    private static let cities: [(cityCode: Int, regionName: String)] = [
        (31040, "안양"),
        (31170, "의왕"),
        (31160, "군포"),
    ]

    private var cache: [GbisStation] = []
    private var cacheLoadedAt: Date?

    init(session: URLSession = .shared, keyStore: APIKeyStore? = nil) {
        self.session = session
        self.keyStore = keyStore ?? APIKeyStore.shared
    }

    func searchStations(keyword: String) async throws -> [GbisStation] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let all = try await loadAllStations()
        let filtered = all.filter { station in
            station.stationName.localizedCaseInsensitiveContains(trimmed)
                || (station.mobileNo?.contains(trimmed) ?? false)
                || (station.regionName?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
        return Array(filtered.prefix(50))
    }

    /// 좌표 기반 빠른 주변 정류소 조회 (TAGO getCrdntPrxmtSttnList — 1회 단일 호출).
    func nearbyStations(
        longitude: Double,
        latitude: Double,
        radiusMeters: Int = 1000
    ) async throws -> [GbisStation] {
        // 1. Direct coordinate lookup (1 fast API request, ~0.2s)
        do {
            let directResults = try await fetchNearbyDirectly(longitude: longitude, latitude: latitude)
            if !directResults.isEmpty {
                AppLog.log("TAGO nearby direct hit: \(directResults.count) stations")
                return Array(directResults.prefix(40))
            }
        } catch {
            AppLog.log("TAGO direct nearby failed: \(error.localizedDescription)")
        }

        // 2. Fallback: Full cached stations scan
        let user = CLLocation(latitude: latitude, longitude: longitude)
        let all = try await loadAllStations()

        var result: [GbisStation] = []
        for station in all {
            guard let lat = station.latitude, let lon = station.longitude else { continue }
            let meters = Int(user.distance(from: CLLocation(latitude: lat, longitude: lon)))
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
        AppLog.log("TAGO nearby scan hits=\(result.count) catalog=\(all.count)")
        if result.isEmpty {
            throw GbisAPIError.emptyResult
        }
        return Array(result.prefix(40))
    }

    private func fetchNearbyDirectly(longitude: Double, latitude: Double) async throws -> [GbisStation] {
        guard let serviceKey = keyStore.serviceKey, !serviceKey.isEmpty else {
            throw GbisAPIError.missingServiceKey
        }
        guard let url = DataGoKrURL.make(
            base: baseURL,
            path: "getCrdntPrxmtSttnList",
            query: [
                "gpsLati": String(format: "%.6f", latitude),
                "gpsLong": String(format: "%.6f", longitude),
                "numOfRows": "50",
                "pageNo": "1",
                "_type": "json",
            ],
            serviceKey: serviceKey
        ) else {
            throw GbisAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        AppLog.log("TAGO GET getCrdntPrxmtSttnList lat=\(latitude) lon=\(longitude)")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.log("TAGO HTTP \(status) getCrdntPrxmtSttnList \(AppLog.snippet(String(data: data, encoding: .utf8)))")
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GbisAPIError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }

        let root = try JSONDecoder().decode(TagoStationListRoot.self, from: data)
        guard root.response.header.resultCode == "00" else {
            throw GbisAPIError.apiMessage("TAGO 근접 정류소: \(root.response.header.resultMsg)")
        }

        let user = CLLocation(latitude: latitude, longitude: longitude)
        var result: [GbisStation] = []
        for row in root.response.body.rows {
            guard let station = row.toDomain(regionName: nil) else { continue }
            let distance: Int? = {
                guard let lat = station.latitude, let lon = station.longitude else { return nil }
                return Int(user.distance(from: CLLocation(latitude: lat, longitude: lon)))
            }()
            result.append(
                GbisStation(
                    stationId: station.stationId,
                    stationName: station.stationName,
                    mobileNo: station.mobileNo,
                    regionName: station.regionName,
                    longitude: station.longitude,
                    latitude: station.latitude,
                    distanceMeters: distance
                )
            )
        }
        result.sort { ($0.distanceMeters ?? Int.max) < ($1.distanceMeters ?? Int.max) }
        return result
    }

    private func loadAllStations() async throws -> [GbisStation] {
        if let cacheLoadedAt,
           Date().timeIntervalSince(cacheLoadedAt) < 3600,
           !cache.isEmpty {
            return cache
        }

        var merged: [String: GbisStation] = [:]
        for city in Self.cities {
            let rows = try await fetchAllPages(cityCode: city.cityCode)
            for row in rows {
                guard let station = row.toDomain(regionName: city.regionName) else { continue }
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

    private func fetchAllPages(cityCode: Int) async throws -> [TagoStationRow] {
        var page = 1
        let pageSize = 1000
        var all: [TagoStationRow] = []
        var total = Int.max

        while all.count < total {
            let pageResult = try await fetchPage(cityCode: cityCode, page: page, size: pageSize)
            total = pageResult.total
            if pageResult.rows.isEmpty { break }
            all.append(contentsOf: pageResult.rows)
            if pageResult.rows.count < pageSize { break }
            page += 1
            if page > 10 { break }
        }
        return all
    }

    private func fetchPage(cityCode: Int, page: Int, size: Int) async throws -> (total: Int, rows: [TagoStationRow]) {
        guard let serviceKey = keyStore.serviceKey, !serviceKey.isEmpty else {
            throw GbisAPIError.missingServiceKey
        }
        guard let url = DataGoKrURL.make(
            base: baseURL,
            path: "getSttnNoList",
            query: [
                "cityCode": String(cityCode),
                "numOfRows": String(size),
                "pageNo": String(page),
                "_type": "json",
            ],
            serviceKey: serviceKey
        ) else {
            throw GbisAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        AppLog.log("TAGO GET getSttnNoList city=\(cityCode) page=\(page)")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.log("TAGO HTTP \(status) getSttnNoList \(AppLog.snippet(String(data: data, encoding: .utf8)))")
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GbisAPIError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }

        let root = try JSONDecoder().decode(TagoStationListRoot.self, from: data)
        guard root.response.header.resultCode == "00" else {
            throw GbisAPIError.apiMessage("TAGO 정류소 \(root.response.header.resultMsg)")
        }
        AppLog.log("TAGO stations city=\(cityCode) rows=\(root.response.body.rows.count) total=\(root.response.body.totalCount)")
        return (root.response.body.totalCount, root.response.body.rows)
    }
}

enum DataGoKrURL {
    /// data.go.kr 키는 한 번만 percent-encode. URLComponents/URLQueryItem 이중 인코딩 금지.
    static func make(base: URL, path: String, query: [String: String], serviceKey: String) -> URL? {
        let keyQueryValue: String
        if serviceKey.contains("%") {
            keyQueryValue = serviceKey
        } else {
            var keyAllowed = CharacterSet.alphanumerics
            keyAllowed.insert(charactersIn: "-._~")
            keyQueryValue = serviceKey.addingPercentEncoding(withAllowedCharacters: keyAllowed) ?? serviceKey
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
        let urlString = base.appending(path: path).absoluteString + "?" + pairs.joined(separator: "&")
        return URL(string: urlString)
    }
}

private struct TagoStationListRoot: Decodable {
    let response: Envelope
    struct Envelope: Decodable {
        let header: Header
        let body: Body
    }
    struct Header: Decodable {
        let resultCode: String
        let resultMsg: String
    }
    struct Body: Decodable {
        let totalCount: Int
        let rows: [TagoStationRow]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            totalCount = (try? container.decode(Int.self, forKey: .totalCount)) ?? 0
            if let items = try? container.decode(Items.self, forKey: .items) {
                rows = items.item ?? []
            } else {
                rows = []
            }
        }

        enum CodingKeys: String, CodingKey { case items, totalCount }
    }
    struct Items: Decodable {
        let item: [TagoStationRow]?

        init(from decoder: Decoder) throws {
            if let single = try? decoder.singleValueContainer() {
                if single.decodeNil() {
                    item = nil
                    return
                }
                if (try? single.decode(String.self)) != nil {
                    item = nil
                    return
                }
            }
            let keyed = try decoder.container(keyedBy: CodingKeys.self)
            if let array = try? keyed.decode([TagoStationRow].self, forKey: .item) {
                item = array
            } else if let one = try? keyed.decode(TagoStationRow.self, forKey: .item) {
                item = [one]
            } else {
                item = nil
            }
        }

        enum CodingKeys: String, CodingKey { case item }
    }
}

struct TagoStationRow: Decodable {
    let nodeid: String
    let nodenm: String
    let nodeno: Int?
    let gpslati: Double?
    let gpslong: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodeid = (try? container.decode(String.self, forKey: .nodeid)) ?? ""
        nodenm = (try? container.decode(String.self, forKey: .nodenm)) ?? ""
        nodeno = Self.int(container, .nodeno)
        gpslati = Self.double(container, .gpslati)
        gpslong = Self.double(container, .gpslong)
    }

    func toDomain(regionName: String?) -> GbisStation? {
        let name = nodenm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let stationId = nodeid.hasPrefix("GGB") ? String(nodeid.dropFirst(3)) : nodeid
        guard !stationId.isEmpty else { return nil }
        return GbisStation(
            stationId: stationId,
            stationName: name,
            mobileNo: nodeno.map(String.init),
            regionName: regionName,
            longitude: gpslong,
            latitude: gpslati,
            distanceMeters: nil
        )
    }

    private enum CodingKeys: String, CodingKey {
        case nodeid, nodenm, nodeno, gpslati, gpslong
    }

    private static func int(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) { return value }
        if let value = try? container.decode(String.self, forKey: key) { return Int(value) }
        return nil
    }

    private static func double(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) { return value }
        if let value = try? container.decode(String.self, forKey: key) { return Double(value) }
        return nil
    }
}
