import MapKit
import SwiftUI

struct NearbyStationsMapView: View {
    @Bindable var viewModel: BusRideViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedStationID: String?

    var body: some View {
        VStack(spacing: 0) {
            map
                .frame(maxHeight: .infinity)

            stationBottomDrawer
                .frame(maxHeight: 280)
        }
        .navigationTitle("내 주변 정류장")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.loadNearbyStations() }
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .bold))
                }
                .disabled(viewModel.isBusy)
            }
        }
        .task {
            await viewModel.requestLocationPermissionOnly()
            if viewModel.hasAPIKey, viewModel.nearbyStations.isEmpty {
                await viewModel.loadNearbyStations()
            } else {
                updateCamera()
            }
        }
        .onChange(of: viewModel.nearbyStations) { _, _ in
            updateCamera()
        }
        .overlay {
            if viewModel.isBusy {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("주변 정류장 탐색 중…")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var map: some View {
        Map(position: $position, selection: $selectedStationID) {
            UserAnnotation()

            ForEach(viewModel.nearbyStations) { station in
                if let coordinate = station.coordinate {
                    Annotation(station.stationName, coordinate: coordinate, anchor: .bottom) {
                        VStack(spacing: 3) {
                            let isSelected = (station.stationId == selectedStationID)
                            Image(systemName: "bus.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(
                                    isSelected ? Color.orange : Color.teal,
                                    in: Circle()
                                )
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)

                            if let meters = station.distanceMeters {
                                Text(distanceLabel(meters))
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                        }
                    }
                    .tag(station.stationId)
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onChange(of: selectedStationID) { _, newValue in
            guard let newValue,
                  let station = viewModel.nearbyStations.first(where: { $0.stationId == newValue })
            else { return }
            Task {
                await viewModel.selectNearbyStation(station)
                dismiss()
            }
        }
    }

    private var stationBottomDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("주변 정류장 목록")
                    .font(.subheadline.bold())
                Spacer()
                if let message = viewModel.locationStatusMessage {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if viewModel.nearbyStations.isEmpty && !viewModel.isBusy {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "location.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("주변에 정류장이 없거나 위치 정보를 불러올 수 없습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(viewModel.nearbyStations) { station in
                        Button {
                            Task {
                                await viewModel.selectNearbyStation(station)
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.teal)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(station.stationName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 6) {
                                        if let meters = station.distanceMeters {
                                            Text(distanceLabel(meters))
                                                .font(.caption2.bold().monospacedDigit())
                                                .foregroundStyle(.teal)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.teal.opacity(0.12), in: Capsule())
                                        }
                                        if !station.subtitle.isEmpty {
                                            Text(station.subtitle)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func distanceLabel(_ meters: Int) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", Double(meters) / 1000)
        }
        return "\(meters)m"
    }

    private func updateCamera() {
        let coords = viewModel.nearbyStations.compactMap(\.coordinate)
        if let user = viewModel.userCoordinate {
            if coords.isEmpty {
                position = .region(
                    MKCoordinateRegion(
                        center: user,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            } else {
                let all = coords + [user]
                position = .region(regionFitting(all))
            }
        } else if !coords.isEmpty {
            position = .region(regionFitting(coords))
        }
    }

    private func regionFitting(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        for c in coordinates.dropFirst() {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.008),
            longitudeDelta: max((maxLon - minLon) * 1.6, 0.008)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
