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
        .navigationTitle("주변 정류장 지도")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.loadNearbyStations() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("새로고침")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.0, green: 0.78, blue: 0.78).opacity(0.15), in: Capsule())
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
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("주변 정류장 탐색 중...")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(20)
                    .background(Color(white: 0.15).opacity(0.95), in: RoundedRectangle(cornerRadius: 14))
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
                        VStack(spacing: 2) {
                            let isSelected = (station.stationId == selectedStationID)
                            VStack(spacing: 1) {
                                Image(systemName: "bus.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(7)
                            .background(
                                isSelected ? Color(red: 1.0, green: 0.55, blue: 0.0) : Color(red: 0.0, green: 0.78, blue: 0.78),
                                in: Circle()
                            )
                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)

                            if let meters = station.distanceMeters {
                                Text(distanceLabel(meters))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(white: 0.15).opacity(0.9), in: Capsule())
                                    .foregroundStyle(.white)
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
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.0, green: 0.78, blue: 0.78))
                    Text("주변 정류장 (\(viewModel.nearbyStations.count)개)")
                        .font(.system(size: 13, weight: .bold))
                }
                Spacer()
                if let message = viewModel.locationStatusMessage {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))

            if viewModel.nearbyStations.isEmpty && !viewModel.isBusy {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("주변에 정류장이 없거나 위치 정보를 불러올 수 없습니다.")
                        .font(.system(size: 12))
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
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color(red: 0.0, green: 0.78, blue: 0.78))
                                    .frame(width: 30, height: 30)
                                    .background(Color(red: 0.0, green: 0.78, blue: 0.78).opacity(0.12), in: Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(station.stationName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 6) {
                                        if let meters = station.distanceMeters {
                                            Text(distanceLabel(meters))
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundStyle(Color(red: 0.0, green: 0.78, blue: 0.78))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color(red: 0.0, green: 0.78, blue: 0.78).opacity(0.12), in: Capsule())
                                        }
                                        if !station.subtitle.isEmpty {
                                            Text(station.subtitle)
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
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
