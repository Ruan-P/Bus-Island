import Foundation

/// TAGO (국토교통부) 버스도착정보 — 남은 정거장 조회
/// https://apis.data.go.kr/1613000/ArvlInfoInqireService
///
/// GBIS busarrivalservice 500/장애 시 fallback으로 사용.
/// nodeId = "GGB" + GBIS stationId (실측 검증), cityCode는 정류소 소속 시군 기준.
actor TagoArrivalClient {
    static let shared = TagoArrivalClient()

    private let baseURL = URL(string: "https://apis.data.go.kr/1613000/ArvlInfoInqireService")!
    private let session: URLSession
    private let keyStore: APIKeyStore

    /// TAGO 도시코드 (getCtyCodeList 실측). key = 경기 시군 행정구역코드(SIGUN_CD)
    private static let cityCodeBySigunCode: [String: Int] = [
        "41170": 31170, // 안양
        "41190": 31180, // 의왕
        "41110": 31160, // 군포
    ]

    init(session: URLSession = .shared, keyStore: APIKeyStore? = nil) {
        self.session = session
        self.keyStore = keyStore ?? APIKeyStore.shared
    }

    /// 남은 정거장 수 조회.
    /// - Parameters:
    ///   - stationId: GBIS stationId (TAGO nodeId = "GGB" + stationId)
    ///   - routeId: GBIS routeId (TAGO routeid = "GGB" + routeId, 아직 사용 안 함)
    ///   - cityCode: TAGO 도시코드 (없으면 추정 실패 시 nil 반환)
    func remainingStops(stationId: String, routeId: String, cityCode: Int?) async throws -> Int? {
        guard let cityCode else { return nil }
        let nodeId = "GGB" + stationId

        var components = URLComponents(url: baseURL.appending(path: "getSttnAcctoArvlPrearngeInfoList"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "serviceKey", value: Self.encodedKey(keyStore.serviceKey)),
            URLQueryItem(name: "cityCode", value: String(cityCode)),
            URLQueryItem(name: "nodeId", value: nodeId),
            URLQueryItem(name: "_type", value: "json"),
        ]
        guard let url = components.url else {
            throw GbisAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GbisAPIError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }

        // TAGO 응답: {"response":{"header":{...},"body":{"items":{"item":{...}},"totalCount":..}}}
        struct Envelope: Decodable {
            struct Header: Decodable { let resultCode: String; let resultMsg: String }
            struct Body: Decodable {
                struct Items: Decodable {
                    struct Item: Decodable {
                        let arrprevstationcnt: Int?
                    }
                    let item: Item?
                }
                let items: Items?
                let totalCount: Int
            }
            let header: Header
            let body: Body
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.header.resultCode == "00" else {
            return nil
        }
        if let stops = envelope.body.items?.item?.arrprevstationcnt {
            return max(0, stops)
        }
        return nil
    }

    private static func encodedKey(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return "" }
        if key.contains("%") { return key }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
    }
}
