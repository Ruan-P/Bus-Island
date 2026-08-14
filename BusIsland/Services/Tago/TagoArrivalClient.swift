import Foundation

/// TAGO (국토교통부) 버스도착정보 — 남은 정거장 조회
/// https://apis.data.go.kr/1613000/ArvlInfoInqireService
///
/// GBIS busarrivalservice 장애 시 fallback.
/// nodeId = "GGB" + GBIS stationId (실측).
actor TagoArrivalClient {
    static let shared = TagoArrivalClient()

    private let baseURL = URL(string: "https://apis.data.go.kr/1613000/ArvlInfoInqireService")!
    private let session: URLSession
    private let keyStore: APIKeyStore

    init(session: URLSession = .shared, keyStore: APIKeyStore? = nil) {
        self.session = session
        self.keyStore = keyStore ?? APIKeyStore.shared
    }

    func remainingStops(stationId: String, routeId: String, cityCode: Int?) async throws -> Int? {
        _ = routeId
        guard let cityCode else { return nil }
        guard let serviceKey = keyStore.serviceKey, !serviceKey.isEmpty else {
            throw GbisAPIError.missingServiceKey
        }

        let nodeId = "GGB" + stationId
        guard let url = DataGoKrURL.make(
            base: baseURL,
            path: "getSttnAcctoArvlPrearngeInfoList",
            query: [
                "cityCode": String(cityCode),
                "nodeId": nodeId,
                "_type": "json",
            ],
            serviceKey: serviceKey
        ) else {
            throw GbisAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        AppLog.log("TAGO GET arrival node=\(nodeId) city=\(cityCode)")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.log("TAGO HTTP \(status) arrival \(AppLog.snippet(String(data: data, encoding: .utf8)))")
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GbisAPIError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }

        let root = try JSONDecoder().decode(TagoArrivalRoot.self, from: data)
        guard root.response.header.resultCode == "00" else { return nil }
        if let stops = root.response.body.item?.arrprevstationcnt {
            return max(0, stops)
        }
        return nil
    }
}

private struct TagoArrivalRoot: Decodable {
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
        let item: Items.Item?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard let items = try? container.decode(Items.self, forKey: .items) else {
                item = nil
                return
            }
            item = items.item
        }

        enum CodingKeys: String, CodingKey { case items }
    }
    struct Items: Decodable {
        struct Item: Decodable {
            let arrprevstationcnt: Int?
        }
        let item: Item?

        init(from decoder: Decoder) throws {
            if let single = try? decoder.singleValueContainer() {
                if single.decodeNil() || (try? single.decode(String.self)) != nil {
                    item = nil
                    return
                }
            }
            let keyed = try decoder.container(keyedBy: CodingKeys.self)
            if let one = try? keyed.decode(Item.self, forKey: .item) {
                item = one
            } else if let many = try? keyed.decode([Item].self, forKey: .item) {
                item = many.first
            } else {
                item = nil
            }
        }

        enum CodingKeys: String, CodingKey { case item }
    }
}
