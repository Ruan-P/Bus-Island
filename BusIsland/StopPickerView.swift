import SwiftUI

struct StopPickerView: View {
    let title: String
    let roleLabel: String
    let stops: [GbisRouteStation]
    let selectedID: String?
    let onSelect: (GbisRouteStation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [GbisRouteStation] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return stops }
        return stops.filter {
            $0.stationName.localizedCaseInsensitiveContains(trimmed)
                || "\($0.stationSeq)".contains(trimmed)
                || ($0.mobileNo?.contains(trimmed) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Box
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                TextField("정류장 이름 또는 번호 검색", text: $query)
                    .font(.system(size: 13))
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Stops List
            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("검색된 정류장이 없습니다")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("정류장 이름이나 번호를 다시 확인해 보세요.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    Section {
                        ForEach(filtered) { stop in
                            let isSelected = (selectedID == stop.id || selectedID == stop.stationId)
                            Button {
                                onSelect(stop)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    // Sequence badge
                                    Text(String(format: "%02d", stop.stationSeq))
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(isSelected ? Color.white : Color(red: 1.0, green: 0.55, blue: 0.0))
                                        .frame(width: 32, height: 28)
                                        .background(
                                            isSelected ? Color(red: 1.0, green: 0.55, blue: 0.0) : Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 6)
                                        )

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(stop.stationName)
                                            .font(.system(size: 15, weight: isSelected ? .bold : .semibold))
                                            .foregroundStyle(.primary)

                                        if let mobileNo = stop.mobileNo, !mobileNo.isEmpty {
                                            Text("정류장 번호: \(mobileNo)")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.0))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        HStack {
                            Text(roleLabel)
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text("총 \(filtered.count)개")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RoutePickerView: View {
    let routes: [GbisRoute]
    let selectedID: String?
    let onSelect: (GbisRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [GbisRoute] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return routes }
        return routes.filter {
            $0.routeName.localizedCaseInsensitiveContains(trimmed)
                || $0.subtitle.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Box
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                TextField("노선 번호 또는 방면 검색", text: $query)
                    .font(.system(size: 13))
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bus")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("검색된 노선이 없습니다")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("노선 번호를 다시 확인해 보세요.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    Section {
                        ForEach(filtered) { route in
                            let isSelected = (selectedID == route.routeId)
                            Button {
                                onSelect(route)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    // Bus Icon Badge
                                    Image(systemName: "bus.fill")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(isSelected ? Color.white : Color(red: 0.20, green: 0.48, blue: 0.98))
                                        .frame(width: 34, height: 34)
                                        .background(
                                            isSelected ? Color(red: 0.20, green: 0.48, blue: 0.98) : Color(red: 0.20, green: 0.48, blue: 0.98).opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 8)
                                        )

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                                            Text(route.routeName)
                                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                                .foregroundStyle(.primary)
                                            if let typeName = route.routeTypeName, !typeName.isEmpty {
                                                Text(typeName)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        if let region = route.regionName, !region.isEmpty {
                                            Text(region)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer(minLength: 8)

                                    // Real-time Arrival Badge
                                    if let badgeText = route.arrivalBadgeText {
                                        let isSoon = (route.remainingStops ?? 99) <= 2
                                        let badgeColor = isSoon ? Color(red: 1.0, green: 0.55, blue: 0.0) : Color(red: 0.0, green: 0.78, blue: 0.78)
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(badgeText)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(badgeColor)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(badgeColor.opacity(0.14), in: Capsule())
                                            if let timeText = route.arrivalTimeText {
                                                Text(timeText)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    } else {
                                        Text("운행 대기")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.tertiary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 4))
                                    }

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(Color(red: 0.20, green: 0.48, blue: 0.98))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        HStack {
                            Text("도착 예정 노선")
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text("총 \(filtered.count)개")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("노선 선택")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NearbyStationPickerView: View {
    let stations: [GbisStation]
    let selectedID: String?
    let onSelect: (GbisStation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [GbisStation] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return stations }
        return stations.filter {
            $0.stationName.localizedCaseInsensitiveContains(trimmed)
                || ($0.subtitle.localizedCaseInsensitiveContains(trimmed))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Box
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                TextField("정류장 이름 검색", text: $query)
                    .font(.system(size: 13))
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("검색된 정류장이 없습니다")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("정류장 이름을 다시 확인해 보세요.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    Section {
                        ForEach(filtered) { station in
                            let isSelected = (selectedID == station.stationId)
                            Button {
                                onSelect(station)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    // Distance / Pin Icon
                                    VStack(spacing: 2) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(isSelected ? Color.white : Color(red: 0.0, green: 0.78, blue: 0.78))
                                    }
                                    .frame(width: 32, height: 32)
                                    .background(
                                        isSelected ? Color(red: 0.0, green: 0.78, blue: 0.78) : Color(red: 0.0, green: 0.78, blue: 0.78).opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(station.stationName)
                                            .font(.system(size: 15, weight: isSelected ? .bold : .semibold))
                                            .foregroundStyle(.primary)
                                        if !station.subtitle.isEmpty {
                                            Text(station.subtitle)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    if let meters = station.distanceMeters {
                                        Text(meters >= 1000 ? String(format: "%.1fkm", Double(meters) / 1000) : "\(meters)m")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color(red: 0.0, green: 0.78, blue: 0.78))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(Color(red: 0.0, green: 0.78, blue: 0.78).opacity(0.12), in: Capsule())
                                    }

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundStyle(Color(red: 0.0, green: 0.78, blue: 0.78))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        HStack {
                            Text("정류장 목록")
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text("총 \(filtered.count)개")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("승차 정류장")
        .navigationBarTitleDisplayMode(.inline)
    }
}
