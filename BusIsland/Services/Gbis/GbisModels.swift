import CoreLocation
import Foundation

// MARK: - Domain models

struct GbisStation: Identifiable, Hashable, Sendable {
    var id: String { stationId }
    let stationId: String
    let stationName: String
    let mobileNo: String?
    let regionName: String?
    let longitude: Double?
    let latitude: Double?
    let distanceMeters: Int?

    init(
        stationId: String,
        stationName: String,
        mobileNo: String? = nil,
        regionName: String? = nil,
        longitude: Double? = nil,
        latitude: Double? = nil,
        distanceMeters: Int? = nil
    ) {
        self.stationId = stationId
        self.stationName = stationName
        self.mobileNo = mobileNo
        self.regionName = regionName
        self.longitude = longitude
        self.latitude = latitude
        self.distanceMeters = distanceMeters
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var subtitle: String {
        var parts: [String] = []
        if let distanceMeters {
            if distanceMeters >= 1000 {
                parts.append(String(format: "%.1fkm", Double(distanceMeters) / 1000))
            } else {
                parts.append("\(distanceMeters)m")
            }
        }
        if let regionName, !regionName.isEmpty { parts.append(regionName) }
        if let mobileNo, !mobileNo.isEmpty { parts.append("정류장번호 \(mobileNo)") }
        return parts.joined(separator: " · ")
    }
}

struct GbisRoute: Identifiable, Hashable, Sendable {
    var id: String { routeId }
    let routeId: String
    let routeName: String
    let routeTypeName: String?
    let regionName: String?

    var subtitle: String {
        [routeTypeName, regionName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

struct GbisRouteStation: Identifiable, Hashable, Sendable {
    var id: String { "\(stationId)-\(stationSeq)" }
    let stationId: String
    let stationName: String
    let stationSeq: Int
    let mobileNo: String?
    let turnYn: String?
    let longitude: Double?
    let latitude: Double?

    init(
        stationId: String,
        stationName: String,
        stationSeq: Int,
        mobileNo: String? = nil,
        turnYn: String? = nil,
        longitude: Double? = nil,
        latitude: Double? = nil
    ) {
        self.stationId = stationId
        self.stationName = stationName
        self.stationSeq = stationSeq
        self.mobileNo = mobileNo
        self.turnYn = turnYn
        self.longitude = longitude
        self.latitude = latitude
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct GbisRideSelection: Hashable, Sendable {
    let boardingStation: GbisStation
    let route: GbisRoute
    let destination: GbisRouteStation
    let boardingSeq: Int

    var rideID: String {
        "\(route.routeId)-\(boardingStation.stationId)-\(destination.stationId)"
    }
}

// MARK: - Flexible decoding helpers

struct FlexibleArray<Element: Decodable>: Decodable {
    let items: [Element]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            items = []
        } else if let array = try? container.decode([Element].self) {
            items = array
        } else if let single = try? container.decode(Element.self) {
            items = [single]
        } else {
            items = []
        }
    }
}

struct LosslessStringCodable: Decodable, Sendable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else {
            value = ""
        }
    }

    var intValue: Int? { Int(value) }
}

// MARK: - API DTOs

struct GbisEnvelope<Body: Decodable>: Decodable {
    let response: GbisResponse<Body>
}

struct GbisResponse<Body: Decodable>: Decodable {
    let msgHeader: GbisMsgHeader?
    let msgBody: Body?
}

struct GbisMsgHeader: Decodable {
    let resultCode: LosslessStringCodable?
    let resultMessage: String?

    var isSuccess: Bool {
        guard let code = resultCode?.value else { return true }
        return code == "0" || code == "00"
    }
}

struct GbisViaRouteListBody: Decodable {
    let busRouteList: FlexibleArray<GbisRouteDTO>?
}

struct GbisRouteDTO: Decodable {
    let routeId: LosslessStringCodable?
    let routeName: String?
    let routeTypeName: String?
    let regionName: String?
    let startStationName: String?
    let endStationName: String?

    func toDomain() -> GbisRoute? {
        guard let routeId = routeId?.value, !routeId.isEmpty,
              let routeName, !routeName.isEmpty
        else { return nil }
        let region: String? = {
            if let regionName, !regionName.isEmpty { return regionName }
            let ends = [startStationName, endStationName].compactMap { $0 }.filter { !$0.isEmpty }
            return ends.isEmpty ? nil : ends.joined(separator: " → ")
        }()
        return GbisRoute(
            routeId: routeId,
            routeName: routeName,
            routeTypeName: routeTypeName,
            regionName: region
        )
    }
}

struct GbisRouteStationListBody: Decodable {
    let busRouteStationList: FlexibleArray<GbisRouteStationDTO>?
}

struct GbisRouteStationDTO: Decodable {
    let stationId: LosslessStringCodable?
    let stationName: String?
    let stationSeq: LosslessStringCodable?
    let mobileNo: LosslessStringCodable?
    let turnYn: String?
    let x: LosslessStringCodable?
    let y: LosslessStringCodable?

    func toDomain() -> GbisRouteStation? {
        guard let stationId = stationId?.value, !stationId.isEmpty,
              let stationName, !stationName.isEmpty,
              let stationSeq = stationSeq?.intValue
        else { return nil }
        return GbisRouteStation(
            stationId: stationId,
            stationName: stationName,
            stationSeq: stationSeq,
            mobileNo: mobileNo?.value.trimmingCharacters(in: .whitespacesAndNewlines),
            turnYn: turnYn,
            longitude: Double(x?.value ?? ""),
            latitude: Double(y?.value ?? "")
        )
    }
}

struct GbisArrivalItemBody: Decodable {
    let busArrivalItem: GbisArrivalDTO?
    let busArrivalList: FlexibleArray<GbisArrivalDTO>?
}

struct GbisArrivalDTO: Decodable {
    let locationNo1: LosslessStringCodable?
    let predictTime1: LosslessStringCodable?
    let plateNo1: String?
    let routeId: LosslessStringCodable?
    let routeName: String?
    let routeDestName: String?
    let staOrder: LosslessStringCodable?

    var remainingStops: Int? {
        locationNo1?.intValue
    }
}
