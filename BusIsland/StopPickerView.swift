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
            // Retro Search Box
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                TextField("정류장 이름 또는 번호 검색", text: $query)
                    .font(.system(size: 13, design: .monospaced))
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
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Stops List
            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("⚠️")
                        .font(.system(size: 36))
                    Text("NO STOPS FOUND")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("정류장 이름이나 번호를 다시 확인해 보세요.")
                        .font(.system(size: 11, design: .monospaced))
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
                                    // Sequence badge in retro box
                                    Text(String(format: "%02d", stop.stationSeq))
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundStyle(isSelected ? Color.white : Color(red: 1.0, green: 0.55, blue: 0.0))
                                        .frame(width: 32, height: 28)
                                        .background(
                                            isSelected ? Color(red: 1.0, green: 0.55, blue: 0.0) : Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 6)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke((isSelected ? Color.white : Color(red: 1.0, green: 0.55, blue: 0.0)).opacity(0.35), lineWidth: 1)
                                        )

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(stop.stationName)
                                            .font(.system(size: 15, weight: isSelected ? .black : .bold))
                                            .foregroundStyle(.primary)

                                        if let mobileNo = stop.mobileNo, !mobileNo.isEmpty {
                                            HStack(spacing: 4) {
                                                Text("ID:")
                                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                Text(mobileNo)
                                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }

                                    Spacer()

                                    if isSelected {
                                        Text("[선택됨]")
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.0))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.4), lineWidth: 1)
                                            )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        HStack {
                            Text("◆ \(roleLabel)")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                            Spacer()
                            Text("TOTAL: \(filtered.count)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
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
            // Retro Search Box
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                TextField("노선 번호 또는 지역 검색", text: $query)
                    .font(.system(size: 13, design: .monospaced))
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
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("🚌")
                        .font(.system(size: 36))
                    Text("NO ROUTES FOUND")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("검색된 노선이 없습니다.")
                        .font(.system(size: 11, design: .monospaced))
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
                                    // Retro Pixel Bus Badge
                                    VStack(spacing: 2) {
                                        Text("BUS")
                                            .font(.system(size: 8, weight: .black, design: .monospaced))
                                            .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color(red: 0.25, green: 0.55, blue: 1.0))
                                        Image(systemName: "bus.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(isSelected ? Color.white : Color(red: 0.25, green: 0.55, blue: 1.0))
                                    }
                                    .frame(width: 36, height: 36)
                                    .background(
                                        isSelected ? Color(red: 0.25, green: 0.55, blue: 1.0) : Color(red: 0.25, green: 0.55, blue: 1.0).opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke((isSelected ? Color.white : Color(red: 0.25, green: 0.55, blue: 1.0)).opacity(0.35), lineWidth: 1)
                                    )

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                                            Text(route.routeName)
                                                .font(.system(size: 17, weight: .black, design: .monospaced))
                                                .foregroundStyle(.primary)
                                            if let typeName = route.routeTypeName, !typeName.isEmpty {
                                                Text(typeName)
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 4))
                                            }
                                        }
                                        if let region = route.regionName, !region.isEmpty {
                                            Text("› \(region)")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer(minLength: 8)

                                    // Real-time Arrival Badge (Retro Arcade Style)
                                    if let badgeText = route.arrivalBadgeText {
                                        let isSoon = (route.remainingStops ?? 99) <= 2
                                        let badgeColor = isSoon ? Color(red: 1.0, green: 0.55, blue: 0.0) : Color(red: 0.15, green: 0.85, blue: 0.70)
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("[ \(badgeText) ]")
                                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                                .foregroundStyle(badgeColor)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(badgeColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(badgeColor.opacity(0.35), lineWidth: 1)
                                                )
                                            if let timeText = route.arrivalTimeText {
                                                // timeText is already formatted as "약 N분", so render directly without repeating "약"
                                                Text(timeText)
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    } else {
                                        Text("[대기]")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 4))
                                    }

                                    if isSelected {
                                        Text("✔")
                                            .font(.system(size: 12, weight: .black, design: .monospaced))
                                            .foregroundStyle(Color(red: 0.25, green: 0.55, blue: 1.0))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        HStack {
                            Text("◆ ARRIVING BUSES")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                            Spacer()
                            Text("TOTAL: \(filtered.count)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
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
            // Retro Search Box
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                TextField("정류장 이름 검색", text: $query)
                    .font(.system(size: 13, design: .monospaced))
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
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("📍")
                        .font(.system(size: 36))
                    Text("NO STATIONS FOUND")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("검색 결과가 없습니다.")
                        .font(.system(size: 11, design: .monospaced))
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
                                    // Retro Station Pin Badge
                                    VStack(spacing: 2) {
                                        Text("STN")
                                            .font(.system(size: 8, weight: .black, design: .monospaced))
                                            .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color(red: 0.15, green: 0.85, blue: 0.70))
                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(isSelected ? Color.white : Color(red: 0.15, green: 0.85, blue: 0.70))
                                    }
                                    .frame(width: 36, height: 36)
                                    .background(
                                        isSelected ? Color(red: 0.15, green: 0.85, blue: 0.70) : Color(red: 0.15, green: 0.85, blue: 0.70).opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke((isSelected ? Color.white : Color(red: 0.15, green: 0.85, blue: 0.70)).opacity(0.35), lineWidth: 1)
                                    )

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(station.stationName)
                                            .font(.system(size: 15, weight: isSelected ? .black : .bold))
                                            .foregroundStyle(.primary)
                                        if !station.subtitle.isEmpty {
                                            Text("› \(station.subtitle)")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if isSelected {
                                        Text("[선택됨]")
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                            .foregroundStyle(Color(red: 0.15, green: 0.85, blue: 0.70))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color(red: 0.15, green: 0.85, blue: 0.70).opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(Color(red: 0.15, green: 0.85, blue: 0.70).opacity(0.4), lineWidth: 1)
                                            )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        HStack {
                            Text("◆ NEARBY STATIONS")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                            Spacer()
                            Text("TOTAL: \(filtered.count)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
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
