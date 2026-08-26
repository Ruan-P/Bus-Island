import CoreLocation
import Foundation

// MARK: - Seoul Bus API Response DTOs (JSON / XML)

public struct SeoulBusResponseHeader: Decodable, Sendable {
    public let headerCd: String?
    public let headerMsg: String?
    public let itemCount: Int?

    public var isSuccess: Bool {
        headerCd == "0" || headerCd == "00" || headerCd == nil
    }
}

public struct SeoulBusResponseBody<T: Decodable>: Decodable {
    public let itemList: FlexibleArray<T>?

    public var items: [T] {
        itemList?.items ?? []
    }
}

public struct SeoulBusEnvelope<T: Decodable>: Decodable {
    public let msgHeader: SeoulBusResponseHeader?
    public let msgBody: SeoulBusResponseBody<T>?
}

// MARK: - Station DTO

public struct SeoulStationDTO: Decodable, Sendable {
    public let stId: String?
    public let stNm: String?
    public let arsId: String?
    public let tmX: String?
    public let tmY: String?
    public let posX: String?
    public let posY: String?

    public func toDomain() -> GbisStation? {
        guard let stId, !stId.isEmpty, let stNm, !stNm.isEmpty else { return nil }
        let lat = Double(posY ?? tmY ?? "")
        let lon = Double(posX ?? tmX ?? "")
        let mobile = (arsId == "0" || arsId == "00000") ? nil : arsId
        return GbisStation(
            stationId: "SEL:\(stId)",
            stationName: stNm,
            mobileNo: mobile,
            regionName: "서울",
            longitude: lon,
            latitude: lat
        )
    }
}

// MARK: - Route DTO

public struct SeoulRouteDTO: Decodable, Sendable {
    public let busRouteId: String?
    public let busRouteNm: String?
    public let routeType: String?
    public let stStationNm: String?
    public let edStationNm: String?

    public var routeTypeName: String {
        switch routeType {
        case "1": return "공항버스"
        case "2": return "마을버스"
        case "3": return "간선버스"
        case "4": return "지선버스"
        case "5": return "순환버스"
        case "6": return "광역버스"
        case "7": return "인천버스"
        case "8": return "경기버스"
        case "9": return "폐지노선"
        case "0": return "공용버스"
        default: return "서울버스"
        }
    }

    public func toDomain() -> GbisRoute? {
        guard let busRouteId, !busRouteId.isEmpty, let busRouteNm, !busRouteNm.isEmpty else { return nil }
        return GbisRoute(
            routeId: "SEL:\(busRouteId)",
            routeName: busRouteNm,
            routeTypeName: routeTypeName,
            regionName: "서울",
            remainingStops: nil,
            predictTimeMinutes: nil,
            nextBus: nil
        )
    }
}

// MARK: - Station Route with Arrival DTO

public struct SeoulStationRouteDTO: Decodable, Sendable {
    public let busRouteId: String?
    public let busRouteNm: String?
    public let busRouteType: String?
    public let arrmsg1: String?
    public let arrmsg2: String?
    public let traTime1: String?
    public let traTime2: String?
    public let vehId1: String?
    public let plainNo1: String?
    public let vehId2: String?
    public let plainNo2: String?

    public func toDomain() -> GbisRoute? {
        guard let busRouteId, !busRouteId.isEmpty, let busRouteNm, !busRouteNm.isEmpty else { return nil }

        let parsed1 = SeoulBusArrivalParser.parse(arrmsg: arrmsg1, traTime: traTime1)
        let parsed2 = SeoulBusArrivalParser.parse(arrmsg: arrmsg2, traTime: traTime2)

        let nextBus: GbisNextBus?
        if parsed2.remainingStops != nil || parsed2.predictMinutes != nil {
            nextBus = GbisNextBus(
                remainingStops: parsed2.remainingStops,
                predictTimeMinutes: parsed2.predictMinutes,
                plateNo: plainNo2
            )
        } else {
            nextBus = nil
        }

        let typeName: String
        switch busRouteType {
        case "1": typeName = "공항"
        case "2": typeName = "마을"
        case "3": typeName = "간선"
        case "4": typeName = "지선"
        case "5": typeName = "순환"
        case "6": typeName = "광역"
        default: typeName = "서울"
        }

        return GbisRoute(
            routeId: "SEL:\(busRouteId)",
            routeName: busRouteNm,
            routeTypeName: typeName,
            regionName: "서울",
            remainingStops: parsed1.remainingStops,
            predictTimeMinutes: parsed1.predictMinutes,
            nextBus: nextBus
        )
    }
}

// MARK: - Route Station (경유 정류소) DTO

public struct SeoulRouteStationDTO: Decodable, Sendable {
    public let busRouteId: String?
    public let seq: String?
    public let section: String?
    public let station: String?
    public let stationNm: String?
    public let stationNo: String?
    public let arsId: String?
    public let posX: String?
    public let posY: String?

    public func toDomain() -> GbisRouteStation? {
        guard let station, !station.isEmpty, let stationNm, !stationNm.isEmpty,
              let seqInt = Int(seq ?? "0"), seqInt > 0 else { return nil }
        let lat = Double(posY ?? "")
        let lon = Double(posX ?? "")
        let mobile = (arsId == "0" || arsId == "00000") ? (stationNo == "0" ? nil : stationNo) : arsId
        return GbisRouteStation(
            stationId: "SEL:\(station)",
            stationName: stationNm,
            stationSeq: seqInt,
            mobileNo: mobile,
            turnYn: nil,
            longitude: lon,
            latitude: lat
        )
    }
}

// MARK: - Arrival Parsing Utility

public enum SeoulBusArrivalParser {
    /// 서울 버스 도착 메시지 `arrmsg1` (예: `3분20초후[2번째 전]`, `곧 도착`, `운행종료`, `출발대기`) 파싱
    public static func parse(arrmsg: String?, traTime: String?) -> (remainingStops: Int?, predictMinutes: Int?) {
        guard let arrmsg, !arrmsg.isEmpty else {
            return (nil, nil)
        }

        var stops: Int? = nil
        var minutes: Int? = nil

        // 1. [N번째 전] 패턴 추출
        if let range = arrmsg.range(of: #"\[([0-9]+)번째\s*전\]"#, options: .regularExpression) {
            let matched = String(arrmsg[range])
            let digits = matched.filter { $0.isNumber }
            if let n = Int(digits) {
                stops = n
            }
        } else if arrmsg.contains("곧 도착") || arrmsg.contains("진입대기") {
            stops = 0
            minutes = 1
        }

        // 2. 시간(분) 계산 (traTime 우선 또는 메시지 내 파싱)
        if let traTime, let sec = Int(traTime), sec > 0 {
            minutes = max(1, (sec + 30) / 60)
        } else if let range = arrmsg.range(of: #"([0-9]+)분"#, options: .regularExpression) {
            let matched = String(arrmsg[range])
            let digits = matched.filter { $0.isNumber }
            if let m = Int(digits) {
                minutes = m
            }
        }

        return (stops, minutes)
    }
}
