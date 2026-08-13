import CoreLocation
import Foundation

/// TAGO (국토교통부) 버스정류소정보 — 정류소 목록/검색/근처 조회
/// https://apis.data.go.kr/1613000/BusSttnInfoInqireService
///
/// gg.go.kr BusStation 중단에 따른 대체 공급원.
/// getSttnNoList가 도시 전체 정류소(이름/좌표/정류소번호 포함)를 반환하므로
/// 도시별 전체 캐시 + GPS 거리 필터로 근처 정류장과 이름 검색을 제공한다.
///
/// nodeId 규칙 (실측 검증): `nodeId = "GGB" + GBIS stationId`
/// 역변환: GBIS stationId = nodeId에서 "GGB" 제거
actor TagoStationClient {
    static let shared = TagoStationClient()

    private let baseURL = URL(string: "https://apis.data.go.kr/1613000/BusSttnInfoInqireService")!
    private let session: URLSession
    private let keyStore: APIKeyStore

    /// TAGO 도시코드 (getCtyCodeList 실측). key = 경기 시군 행정구역코드(SIGUN_CD)
    private static let cityCodeBySigunCode: [String: Int] = [
        "41170": 31170, // 안양
        "41190": 31180, // 의왕
        "41110": 31160, // 군포
    ]
    private static let regionNameBySigunCode: [String: String] = [
        "41170": "안양",
        "41190": "의왕",
        "41110": "군포",
    ]
    /// 안양 / 의왕 / 군포
    private static let targetSigunCodes = ["41170", "41190", "41110"]

    private var cache: [GbisStation] = []
    private var cacheLoadedAt: Date?

    init(session: URLSession = .shared, keyStore: APIKeyStore? = nil) {
        self.session = session
        self.keyStore = keyStore ?? APIKeyStore.shared
    }

    // MARK: - Public

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

    func nearbyStations(
        longitude: Double,
        latitude: Double,
        radiusMeters: Int = 800
    ) async throws -> [GbisStation] {
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
        if result.isEmpty {
            throw GbisAPIError.emptyResult
        }
        return Array(result.prefix(40))
    }

    // MARK: - Private

    private func loadAllStations() async throws -> [GbisStation] {
        if let cacheLoadedAt,
           Date().timeIntervalSince(cacheLoadedAt) < 3600,
           !cache.isEmpty {
            return cache
        }

        var merged: [String: GbisStation] = [:]
        for sigunCode in Self.targetSigunCodes {
            guard let cityCode = Self.cityCodeBySigunCode[sigunCode] else { continue }
            let rows = try await fetchAllPages(cityCode: cityCode)
            for row in rows {
                guard let station = row.toDomain(regionName: Self.regionNameBySigunCode[sigunCode]) else { continue }
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
        let keyQueryValue: String
        if serviceKey.contains("%") {
            keyQueryValue = serviceKey
        } else {
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            keyQueryValue = serviceKey.addingPercentEncoding(withAllowedCharacters: allowed) ?? serviceKey
        }

        var components = URLComponents(url: baseURL.appending(path: "getSttnNoList"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "serviceKey", value: keyQueryValue),
            URLQueryItem(name: "cityCode", value: String(cityCode)),
            URLQueryItem(name: "numOfRows", value: String(size)),
            URLQueryItem(name: "pageNo", value: String(page)),
            URLQueryItem(name: "_type", value: "json"),
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

        // TAGO 응답: {"response":{"header":{...},"body":{"items":{"item":[...]},"numOfRows":..,"pageNo":..,"totalCount":..}}}
        // 결과 없으면 items가 "" 빈 문자열로 옴 → 유연 디코딩
        struct Envelope: Decodable {
            struct Header: Decodable { let resultCode: String; let resultMsg: String }
            struct Body: Decodable {
                struct Items: Decodable {
                    let item: [TagoStationRow]?
                    init(from decoder: Decoder) throws {
                        let container = try decoder.singleValueContainer()
                        if container.decodeNil() {
                            item = nil
                        } else if let array = try? container.decode([TagoStationRow].self) {
                            item = array
                        } else if let single = try? container.decode(TagoStationRow.self) {
                            item = [single]
                        } else {
                            item = nil
                        }
                    }
                }
                let items: Items?
                let totalCount: Int
            }
            let header: Header
            let body: Body
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.header.resultCode == "00" else {
            throw GbisAPIError.apiMessage("TAGO 정류소 \(envelope.header.resultMsg)")
        }
        let rows = envelope.body.items?.item ?? []
        return (envelope.body.totalCount, rows)
    }
}

/// getSttnNoList 응답 1건 (JSON 키 그대로 매핑)
struct TagoStationRow: Decodable {
    let nodeid: String
    let nodenm: String
    let nodeno: Int?
    let gpslati: Double?
    let gpslong: Double?

    func toDomain(regionName: String?) -> GbisStation? {
        let name = nodenm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        // nodeId "GGB..." → GBIS stationId (역변환, 실측 검증 완료)
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
}
