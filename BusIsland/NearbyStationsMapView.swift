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

            stationList
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
                }
                .disabled(viewModel.isBusy)
            }
        }
        .task {
            // Always ask location first so the system prompt appears on this screen.
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
                ProgressView("주변 정류장 찾는 중…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
                            Image(systemName: "bus.fill")
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(station.stationId == selectedStationID ? Color.orange : Color.blue, in: Circle())
                            if let meters = station.distanceMeters {
                                Text(distanceLabel(meters))
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.thinMaterial, in: Capsule())
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

    private var stationList: some View {
        List {
            if let message = viewModel.locationStatusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.nearbyStations.isEmpty && !viewModel.isBusy {
                Text("주변에 정류장이 없거나 위치를 아직 못 가져왔습니다.")
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.nearbyStations) { station in
                Button {
                    Task {
                        await viewModel.selectNearbyStation(station)
                        dismiss()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(station.stationName)
                                .foregroundStyle(.primary)
                            HStack(spacing: 8) {
                                if let meters = station.distanceMeters {
                                    Text(distanceLabel(meters))
                                        .font(.caption.monospacedDigit())
                                }
                                if !station.subtitle.isEmpty {
                                    Text(station.subtitle)
                                        .font(.caption)
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .listStyle(.plain)
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
