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
        List {
            Section {
                TextField("정류장 이름 또는 순번", text: $query)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
            }

            Section {
                if filtered.isEmpty {
                    Text("검색 결과가 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { stop in
                        Button {
                            onSelect(stop)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stop.stationName)
                                        .foregroundStyle(.primary)
                                    Text("순번 \(stop.stationSeq)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedID == stop.id || selectedID == stop.stationId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("\(roleLabel) · \(filtered.count)개")
            }
        }
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
        List {
            Section {
                TextField("노선 번호 또는 지역", text: $query)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
            }

            Section {
                if filtered.isEmpty {
                    Text("검색 결과가 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { route in
                        Button {
                            onSelect(route)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(route.routeName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if !route.subtitle.isEmpty {
                                        Text(route.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedID == route.routeId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("노선 \(filtered.count)개")
            }
        }
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
        List {
            Section {
                TextField("정류장 이름", text: $query)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
            }

            Section {
                if filtered.isEmpty {
                    Text("검색 결과가 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { station in
                        Button {
                            onSelect(station)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(station.stationName)
                                        .foregroundStyle(.primary)
                                    if !station.subtitle.isEmpty {
                                        Text(station.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedID == station.stationId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("근처 \(filtered.count)개")
            }
        }
        .navigationTitle("승차 정류장")
        .navigationBarTitleDisplayMode(.inline)
    }
}
