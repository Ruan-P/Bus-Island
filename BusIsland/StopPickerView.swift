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
                    .foregroundStyle(.secondary)
                TextField("정류장 이름 또는 번호 검색", text: $query)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Stops List
            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("검색 결과가 없습니다")
                        .font(.headline)
                    Text("정류장 이름이나 번호를 다시 확인해보세요.")
                        .font(.footnote)
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
                                HStack(spacing: 14) {
                                    // Sequence badge
                                    Text("\(stop.stationSeq)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                                        .frame(width: 28, height: 28)
                                        .background(isSelected ? Color.blue : Color(uiColor: .tertiarySystemFill), in: Circle())

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(stop.stationName)
                                            .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                                            .foregroundStyle(.primary)

                                        if let mobileNo = stop.mobileNo, !mobileNo.isEmpty {
                                            Text("정류장 번호: \(mobileNo)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("\(roleLabel) · 총 \(filtered.count)개")
                            .font(.caption.bold())
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
                    .foregroundStyle(.secondary)
                TextField("노선 번호 또는 지역 검색", text: $query)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bus")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("검색된 노선이 없습니다")
                        .font(.headline)
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
                                    Image(systemName: "bus.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(isSelected ? Color.white : Color.blue)
                                        .frame(width: 34, height: 34)
                                        .background(isSelected ? Color.blue : Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

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
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer(minLength: 8)

                                    // 실시간 도착 상태 배지 (몇 정거장 전 / 약 N분 후)
                                    if let badgeText = route.arrivalBadgeText {
                                        let isSoon = (route.remainingStops ?? 99) <= 2
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(badgeText)
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(isSoon ? Color.orange : Color.teal)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    (isSoon ? Color.orange : Color.teal).opacity(0.14),
                                                    in: Capsule()
                                                )
                                            if let timeText = route.arrivalTimeText {
                                                Text(timeText)
                                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(.secondary)
                                                    .monospacedDigit()
                                            }
                                        }
                                    } else {
                                        Text("운행 정보 대기")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("도착 예정 노선 · 총 \(filtered.count)개")
                            .font(.caption.bold())
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
                    .foregroundStyle(.secondary)
                TextField("정류장 이름 검색", text: $query)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "location.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("검색 결과가 없습니다")
                        .font(.headline)
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
                                HStack(spacing: 14) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 16))
                                        .foregroundStyle(isSelected ? Color.white : Color.teal)
                                        .frame(width: 32, height: 32)
                                        .background(isSelected ? Color.teal : Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(station.stationName)
                                            .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                                            .foregroundStyle(.primary)
                                        if !station.subtitle.isEmpty {
                                            Text(station.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.teal)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("정류장 · \(filtered.count)개")
                            .font(.caption.bold())
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("정류장 선택")
        .navigationBarTitleDisplayMode(.inline)
    }
}
