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
        .navigationTitle("MAP RADAR")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.loadNearbyStations() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("RADAR")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.15, green: 0.85, blue: 0.70).opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 0.15, green: 0.85, blue: 0.70).opacity(0.35), lineWidth: 1)
                    )
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
                        Text("SCANNING NEARBY...")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(20)
                    .background(Color(white: 0.15).opacity(0.95), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.15, green: 0.85, blue: 0.70).opacity(0.5), lineWidth: 1.5)
                    )
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
                                Text("STN")
                                    .font(.system(size: 7, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                Image(systemName: "bus.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(6)
                            .background(
                                isSelected ? Color(red: 1.0, green: 0.55, blue: 0.0) : Color(red: 0.15, green: 0.85, blue: 0.70),
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)

                            if let meters = station.distanceMeters {
                                Text(distanceLabel(meters))
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color(white: 0.1).opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
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
                    Text("◆")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color(red: 0.15, green: 0.85, blue: 0.70))
                    Text("RADAR TARGETS (\(viewModel.nearbyStations.count))")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                }
                Spacer()
                if let message = viewModel.locationStatusMessage {
                    Text("› \(message)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay(
                Rectangle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            if viewModel.nearbyStations.isEmpty && !viewModel.isBusy {
                VStack(spacing: 8) {
                    Spacer()
                    Text("📍")
                        .font(.system(size: 28))
                    Text("주변에 정류장이 없거나 위치 정보를 불러올 수 없습니다.")
                        .font(.system(size: 11, design: .monospaced))
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
                                VStack(spacing: 1) {
                                    Text("STN")
                                        .font(.system(size: 7, weight: .black, design: .monospaced))
                                        .foregroundStyle(Color(red: 0.15, green: 0.85, blue: 0.70))
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(red: 0.15, green: 0.85, blue: 0.70))
                                }
                                .frame(width: 30, height: 30)
                                .background(Color(red: 0.15, green: 0.85, blue: 0.70).opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(station.stationName)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 6) {
                                        if let meters = station.distanceMeters {
                                            Text("[ \(distanceLabel(meters)) ]")
                                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                                .foregroundStyle(Color(red: 0.15, green: 0.85, blue: 0.70))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color(red: 0.15, green: 0.85, blue: 0.70).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                                        }
                                        if !station.subtitle.isEmpty {
                                            Text("› \(station.subtitle)")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                Text("SELECT ▶")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.15, green: 0.85, blue: 0.70))
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
