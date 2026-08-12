import CoreLocation
import Observation
import SwiftUI

struct ContentView: View {
    @State private var viewModel = BusRideViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BI-GBIS v1.1 build 4")
                            .font(.title2.bold())
                        Text("경기버스 하차알림 · 이 문구가 보이면 새 빌드")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Text("홈 아이콘 이름도 BI-GBIS 여야 합니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label(
                            viewModel.hasAPIKey ? "API 키 설정 (저장됨)" : "API 키 설정 (필수)",
                            systemImage: "key.fill"
                        )
                    }
                }

                if !viewModel.hasAPIKey {
                    Section {
                        Text("data.go.kr Decoding 키를 설정에 저장해야 정류장 검색/GPS가 동작합니다.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                statusSection
                nearbySection
                stationSearchSection
                if !viewModel.stationResults.isEmpty {
                    stationResultsSection
                }
                if viewModel.selectedStation != nil {
                    routesSection
                }
                if viewModel.selectedRoute != nil {
                    destinationSection
                }
                if viewModel.snapshot != nil || viewModel.isActivityRunning {
                    rideSection
                }
            }
            .navigationTitle("BusIsland")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .alert("오류", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .overlay {
                if viewModel.isBusy {
                    ProgressView()
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .task { viewModel.refreshStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.refreshStatus()
                }
            }
            .onAppear { viewModel.refreshStatus() }
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section("상태") {
            HStack {
                Circle()
                    .fill(viewModel.isActivityRunning ? Color.green : Color.secondary)
                    .frame(width: 10, height: 10)
                Text(viewModel.statusText)
                    .font(.subheadline)
            }
        }
    }

    private var nearbySection: some View {
        Section {
            // Always tappable so location permission can be requested even before API key.
            Button {
                Task { await viewModel.requestLocationPermissionOnly() }
            } label: {
                Label("위치 권한 요청", systemImage: "location.circle")
            }

            NavigationLink {
                NearbyStationsMapView(viewModel: viewModel)
            } label: {
                Label("내 주변 정류장 (지도)", systemImage: "map.fill")
            }

            Button {
                Task { await viewModel.loadNearbyStations() }
            } label: {
                Label("GPS로 근처 정류장 불러오기", systemImage: "location.fill")
            }
            .disabled(viewModel.isBusy)

            if !viewModel.nearbyStations.isEmpty {
                ForEach(viewModel.nearbyStations.prefix(8)) { station in
                    Button {
                        Task { await viewModel.selectStation(station) }
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
                            if viewModel.selectedStation?.stationId == station.stationId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("근처 정류장 · GPS / 지도")
        } footer: {
            Text(viewModel.locationStatusMessage ?? "위치 권한 → GPS 불러오기 → 정류장 선택. 지도는 Apple MapKit.")
        }
    }

    private var stationSearchSection: some View {
        Section {
            HStack {
                TextField("정류장 이름 (예: 안양역, 의왕)", text: $viewModel.stationQuery)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.searchStations() }
                    }
                Button("검색") {
                    Task { await viewModel.searchStations() }
                }
                .disabled(!viewModel.hasAPIKey || viewModel.stationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("1. 정류장 이름 검색")
        } footer: {
            Text("탑승(또는 현재) 정류장을 고른 뒤, 그 정류장을 지나는 노선을 선택합니다.")
        }
    }

    private var stationResultsSection: some View {
        Section("정류장 선택") {
            ForEach(viewModel.stationResults) { station in
                Button {
                    Task { await viewModel.selectStation(station) }
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
                        if viewModel.selectedStation?.stationId == station.stationId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
    }

    private var routesSection: some View {
        Section {
            if viewModel.routesAtStation.isEmpty && !viewModel.isBusy {
                Text("이 정류장을 지나는 노선이 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.routesAtStation) { route in
                    Button {
                        Task { await viewModel.selectRoute(route) }
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
                            if viewModel.selectedRoute?.routeId == route.routeId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("2. 경유 노선")
        } footer: {
            if let station = viewModel.selectedStation {
                Text("\(station.stationName) 경유 노선")
            }
        }
    }

    private var destinationSection: some View {
        Section {
            if viewModel.destinationCandidates.isEmpty && !viewModel.isBusy {
                Text("하차 가능한 이후 정류장이 없습니다. 다른 방향 정류장을 선택해 보세요.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.destinationCandidates) { stop in
                    Button {
                        viewModel.selectDestination(stop)
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
                            if viewModel.selectedDestination?.id == stop.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("3. 하차 정류장")
        }
    }

    private var rideSection: some View {
        Section("하차 알림") {
            if let snapshot = viewModel.snapshot {
                LabeledContent("노선", value: snapshot.routeNumber)
                LabeledContent("목적지", value: snapshot.destination)
                LabeledContent("남은 정거장", value: "\(snapshot.remainingStops)")
            }

            Button {
                Task { await viewModel.startTracking() }
            } label: {
                Label("Live Activity 시작", systemImage: "dot.radiowaves.left.and.right")
            }
            .disabled(!viewModel.canStartTracking || viewModel.isBusy)

            Button {
                Task { await viewModel.refreshNow() }
            } label: {
                Label("지금 갱신", systemImage: "arrow.clockwise")
            }
            .disabled(!viewModel.isActivityRunning || viewModel.isBusy)

            Button(role: .destructive) {
                Task { await viewModel.endTracking() }
            } label: {
                Label("알림 종료", systemImage: "xmark.circle")
            }
            .disabled(!viewModel.isActivityRunning || viewModel.isBusy)
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class BusRideViewModel {
    private let client = GbisAPIClient.shared
    private let tracker = GbisRideTracker()
    private let activityService = LiveActivityService()
    private let keyStore = APIKeyStore.shared
    private let locationService = LocationService.shared

    var hasAPIKey = false
    var stationQuery = ""
    var stationResults: [GbisStation] = []
    var nearbyStations: [GbisStation] = []
    var userCoordinate: CLLocationCoordinate2D?
    var locationStatusMessage: String?
    var selectedStation: GbisStation?
    var routesAtStation: [GbisRoute] = []
    var selectedRoute: GbisRoute?
    var routeStations: [GbisRouteStation] = []
    var selectedDestination: GbisRouteStation?
    var snapshot: BusRideSnapshot?
    var isActivityRunning = false
    var isBusy = false
    var errorMessage: String?
    var activitiesEnabled = true

    var destinationCandidates: [GbisRouteStation] {
        guard let boarding = selectedStation else { return routeStations }
        // Prefer stops after the boarding station on this route direction.
        if let boardingOnRoute = routeStations.first(where: { $0.stationId == boarding.stationId }) {
            return routeStations.filter { $0.stationSeq > boardingOnRoute.stationSeq }
        }
        return routeStations
    }

    var canStartTracking: Bool {
        hasAPIKey
            && selectedStation != nil
            && selectedRoute != nil
            && selectedDestination != nil
            && activitiesEnabled
    }

    var statusText: String {
        if !hasAPIKey {
            return "인증키 필요 — 설정에서 저장"
        }
        if !activitiesEnabled {
            return "Live Activities 비활성화 (기기 설정 확인)"
        }
        if isActivityRunning {
            return "Dynamic Island 표시 중 · \(snapshot.map { "\($0.remainingStops)정거장" } ?? "")"
        }
        if selectedDestination != nil {
            return "하차 정류장 선택됨 — 시작 가능"
        }
        if selectedRoute != nil {
            return "하차 정류장을 선택하세요"
        }
        if selectedStation != nil {
            return "경유 노선을 선택하세요"
        }
        return "정류장을 검색하세요"
    }

    func refreshStatus() {
        hasAPIKey = keyStore.hasServiceKey
        activitiesEnabled = activityService.areActivitiesEnabled
        isActivityRunning = activityService.hasActiveActivity
    }

    func searchStations() async {
        await run {
            let results = try await client.searchStations(keyword: stationQuery)
            stationResults = results
            selectedStation = nil
            routesAtStation = []
            selectedRoute = nil
            routeStations = []
            selectedDestination = nil
            if results.isEmpty {
                throw GbisAPIError.emptyResult
            }
        }
    }

    func requestLocationPermissionOnly() async {
        await run {
            locationStatusMessage = "위치 권한 요청 중…"
            _ = try await locationService.ensureWhenInUseAuthorization()
            locationStatusMessage = locationService.isAuthorized
                ? "위치 권한 허용됨 — GPS 불러오기를 누르세요"
                : "위치 권한이 필요합니다"
        }
    }

    func loadNearbyStations() async {
        await run {
            guard hasAPIKey else {
                throw GbisAPIError.missingServiceKey
            }
            locationStatusMessage = "위치 확인 중…"
            let location = try await locationService.currentLocation()
            userCoordinate = location.coordinate
            locationStatusMessage = String(
                format: "현재 위치 · %.5f, %.5f",
                location.coordinate.latitude,
                location.coordinate.longitude
            )
            let results = try await client.nearbyStations(
                longitude: location.coordinate.longitude,
                latitude: location.coordinate.latitude
            )
            nearbyStations = results
            stationResults = results
            selectedStation = nil
            routesAtStation = []
            selectedRoute = nil
            routeStations = []
            selectedDestination = nil
            if results.isEmpty {
                throw GbisAPIError.emptyResult
            }
            locationStatusMessage = "근처 \(results.count)개 정류장"
        }
    }

    func selectStation(_ station: GbisStation) async {
        await run {
            selectedStation = station
            selectedRoute = nil
            routeStations = []
            selectedDestination = nil
            routesAtStation = try await client.routes(at: station.stationId)
            if routesAtStation.isEmpty {
                throw GbisAPIError.emptyResult
            }
        }
    }

    func selectRoute(_ route: GbisRoute) async {
        await run {
            selectedRoute = route
            selectedDestination = nil
            routeStations = try await client.stations(on: route.routeId)
            if routeStations.isEmpty {
                throw GbisAPIError.emptyResult
            }
        }
    }

    func selectDestination(_ stop: GbisRouteStation) {
        selectedDestination = stop
        if let station = selectedStation, let route = selectedRoute {
            snapshot = BusRideSnapshot(
                id: "\(route.routeId)-\(station.stationId)-\(stop.stationId)",
                routeNumber: route.routeName,
                destination: stop.stationName,
                remainingStops: max(0, stop.stationSeq - (routeStations.first(where: { $0.stationId == station.stationId })?.stationSeq ?? 0))
            )
        }
    }

    func startTracking() async {
        guard let station = selectedStation,
              let route = selectedRoute,
              let destination = selectedDestination
        else { return }

        await run {
            let selection = GbisRideSelection(
                boardingStation: station,
                route: route,
                destination: destination
            )
            let initial = try await tracker.makeInitialSnapshot(from: selection)
            try await activityService.start(with: initial)
            snapshot = initial
            isActivityRunning = true

            tracker.startPolling(
                intervalSeconds: 20,
                onUpdate: { [weak self] updated in
                    guard let self else { return }
                    Task { @MainActor in
                        do {
                            try await self.activityService.update(with: updated)
                            self.snapshot = updated
                            self.isActivityRunning = true
                        } catch {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                },
                onError: { [weak self] error in
                    self?.errorMessage = error.localizedDescription
                }
            )
        }
    }

    func refreshNow() async {
        await run {
            let updated = try await tracker.refreshSnapshot()
            try await activityService.update(with: updated)
            snapshot = updated
            isActivityRunning = true
        }
    }

    func endTracking() async {
        await run {
            tracker.reset()
            await activityService.end()
            isActivityRunning = false
        }
    }

    private func run(_ work: () async throws -> Void) async {
        isBusy = true
        defer {
            isBusy = false
            refreshStatus()
        }
        do {
            try await work()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
