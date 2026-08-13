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
                        Text("BI-GBIS v1.1 build 12")
                            .font(.title2.bold())
                        Text("근처정류장: TAGO(1613000) · 도착 fallback: TAGO")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Text(viewModel.keyStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("API 키 설정 (선택)", systemImage: "key.fill")
                    }
                }

                statusSection
                nearbySection
                stationNameSearchSection
                if !viewModel.stationNameResults.isEmpty {
                    stationNameResultsSection
                }
                routeSearchSection
                if !viewModel.routeResults.isEmpty {
                    routeResultsSection
                }
                if viewModel.selectedRoute != nil {
                    boardingSection
                }
                if viewModel.selectedStation != nil, viewModel.selectedRoute != nil {
                    destinationSection
                }
                if viewModel.snapshot != nil || viewModel.isActivityRunning {
                    rideSection
                }
            }
            .navigationTitle("BI-GBIS")
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
                if phase == .active { viewModel.refreshStatus() }
            }
            .onAppear { viewModel.refreshStatus() }
        }
    }

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

    private var routeSearchSection: some View {
        Section {
            HStack {
                TextField("노선 번호 (예: 1-1, 8, 11-2)", text: $viewModel.routeQuery)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.search)
                    .onSubmit { Task { await viewModel.searchRoutes() } }
                Button("검색") {
                    Task { await viewModel.searchRoutes() }
                }
                .disabled(viewModel.routeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isBusy)
            }
        } header: {
            Text("1. 노선 검색")
        } footer: {
            Text("이 API 키는 정류소 검색 권한이 없어 노선 번호로 시작합니다. (노선/도착 API 사용)")
        }
    }

    private var routeResultsSection: some View {
        Section("노선 선택") {
            ForEach(viewModel.routeResults) { route in
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
    }

    private var nearbySection: some View {
        Section {
            Button {
                Task { await viewModel.requestLocationPermissionOnly() }
            } label: {
                Label("위치 권한 요청", systemImage: "location.circle")
            }

            Button {
                Task { await viewModel.loadNearbyStations() }
            } label: {
                Label("GPS 근처 정류장 불러오기", systemImage: "location.fill")
            }
            .disabled(viewModel.isBusy)

            NavigationLink {
                NearbyStationsMapView(viewModel: viewModel)
            } label: {
                Label("지도에서 보기", systemImage: "map.fill")
            }

            if !viewModel.nearbyStations.isEmpty {
                ForEach(viewModel.nearbyStations.prefix(12)) { station in
                    Button {
                        Task { await viewModel.selectNearbyStation(station) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(station.stationName)
                                    .foregroundStyle(.primary)
                                Text(station.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
            Text("0. GPS 근처 정류장")
        } footer: {
            Text(viewModel.locationStatusMessage ?? "TAGO 정류소 (안양·의왕·군포) + GPS 반경 필터")
        }
    }

    private var stationNameSearchSection: some View {
        Section {
            HStack {
                TextField("정류장 이름 (예: 안양역)", text: $viewModel.stationNameQuery)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit { Task { await viewModel.searchStationsByName() } }
                Button("검색") {
                    Task { await viewModel.searchStationsByName() }
                }
                .disabled(viewModel.stationNameQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isBusy)
            }
        } header: {
            Text("정류장 이름 검색")
        }
    }

    private var stationNameResultsSection: some View {
        Section("정류장 선택") {
            ForEach(viewModel.stationNameResults) { station in
                Button {
                    Task { await viewModel.selectNearbyStation(station) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(station.stationName)
                                .foregroundStyle(.primary)
                            Text(station.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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

    private var boardingSection: some View {
        Section {
            if viewModel.routeStations.isEmpty && !viewModel.isBusy {
                Text("정류장 목록이 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                if viewModel.userCoordinate != nil {
                    Button {
                        viewModel.selectNearestBoarding()
                    } label: {
                        Label("내 위치에서 가장 가까운 정류장을 탑승으로", systemImage: "location.north.circle.fill")
                    }
                }
                ForEach(viewModel.routeStations) { stop in
                    Button {
                        viewModel.selectBoardingStop(stop)
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
                            if viewModel.selectedStation?.stationId == stop.stationId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("2. 탑승 정류장")
        }
    }

    private var destinationSection: some View {
        Section {
            if viewModel.destinationCandidates.isEmpty {
                Text("하차 가능한 이후 정류장이 없습니다. 탑승 정류장을 앞쪽으로 바꿔 보세요.")
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
    var routeQuery = ""
    var routeResults: [GbisRoute] = []
    var stationNameQuery = ""
    var stationNameResults: [GbisStation] = []
    var nearbyStations: [GbisStation] = []
    var userCoordinate: CLLocationCoordinate2D?
    var locationStatusMessage: String?
    var selectedStation: GbisStation?
    var selectedRoute: GbisRoute?
    var routeStations: [GbisRouteStation] = []
    var selectedDestination: GbisRouteStation?
    var snapshot: BusRideSnapshot?
    var isActivityRunning = false
    var isBusy = false
    var errorMessage: String?
    var activitiesEnabled = true

    var destinationCandidates: [GbisRouteStation] {
        guard let boarding = selectedStation else { return [] }
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

    var keyStatusText: String {
        keyStore.isUsingBakedDefault ? "API 키: 빌드 기본키" : "API 키: 사용자 저장키"
    }

    var statusText: String {
        if !hasAPIKey { return "인증키 없음" }
        if !activitiesEnabled { return "Live Activities 비활성화" }
        if isActivityRunning {
            return "Island 표시 중 · \(snapshot.map { "\($0.remainingStops)정거장" } ?? "")"
        }
        if selectedDestination != nil { return "하차 선택됨 — 시작 가능" }
        if selectedStation != nil { return "하차 정류장을 선택하세요" }
        if selectedRoute != nil { return "탑승 정류장을 선택하세요" }
        return "노선 번호를 검색하세요"
    }

    func refreshStatus() {
        hasAPIKey = keyStore.hasServiceKey
        activitiesEnabled = activityService.areActivitiesEnabled
        isActivityRunning = activityService.hasActiveActivity
    }

    func searchRoutes() async {
        await run {
            let results = try await client.searchRoutes(keyword: routeQuery)
            routeResults = results
            selectedRoute = nil
            routeStations = []
            selectedDestination = nil
            if results.isEmpty { throw GbisAPIError.emptyResult }
        }
    }

    func searchStationsByName() async {
        await run {
            let results = try await client.searchStationsByName(keyword: stationNameQuery)
            stationNameResults = results
            if results.isEmpty { throw GbisAPIError.emptyResult }
        }
    }

    func selectRoute(_ route: GbisRoute) async {
        await run {
            selectedRoute = route
            selectedDestination = nil
            // Keep boarding if it exists on this route; else clear.
            routeStations = try await client.stations(on: route.routeId)
            if let boarding = selectedStation,
               !routeStations.contains(where: { $0.stationId == boarding.stationId }) {
                selectedStation = nil
            }
            if routeStations.isEmpty { throw GbisAPIError.emptyResult }
        }
    }

    func selectBoardingStop(_ stop: GbisRouteStation) {
        selectedStation = GbisStation(
            stationId: stop.stationId,
            stationName: stop.stationName,
            mobileNo: stop.mobileNo,
            regionName: selectedRoute?.routeName,
            longitude: stop.longitude,
            latitude: stop.latitude
        )
        selectedDestination = nil
        snapshot = nil
    }

    func selectNearestBoarding() {
        guard let user = userCoordinate else { return }
        let userLoc = CLLocation(latitude: user.latitude, longitude: user.longitude)
        let nearest = routeStations.compactMap { stop -> (GbisRouteStation, Int)? in
            guard let c = stop.coordinate else { return nil }
            let m = Int(userLoc.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude)))
            return (stop, m)
        }
        .min(by: { $0.1 < $1.1 })
        if let nearest {
            selectBoardingStop(nearest.0)
            locationStatusMessage = "탑승: \(nearest.0.stationName) (\(nearest.1)m)"
        }
    }

    func selectNearbyStation(_ station: GbisStation) async {
        await run {
            selectedStation = station
            selectedRoute = nil
            selectedDestination = nil
            routeStations = []
            // Load routes currently arriving at this station.
            let routes = try await client.routes(at: station.stationId)
            routeResults = routes
            if routes.count == 1 {
                try await selectRouteInternal(routes[0])
            }
        }
    }

    func selectDestination(_ stop: GbisRouteStation) {
        selectedDestination = stop
        if let station = selectedStation, let route = selectedRoute {
            let boardingSeq = routeStations.first(where: { $0.stationId == station.stationId })?.stationSeq ?? 0
            snapshot = BusRideSnapshot(
                id: "\(route.routeId)-\(station.stationId)-\(stop.stationId)",
                routeNumber: route.routeName,
                destination: stop.stationName,
                remainingStops: max(0, stop.stationSeq - boardingSeq)
            )
        }
    }

    func requestLocationPermissionOnly() async {
        await run {
            locationStatusMessage = "위치 권한 요청 중…"
            _ = try await locationService.ensureWhenInUseAuthorization()
            locationStatusMessage = locationService.isAuthorized
                ? "위치 권한 허용됨"
                : "위치 권한 필요"
        }
    }

    func loadNearbyStations() async {
        await run {
            locationStatusMessage = "위치 확인 중…"
            let location = try await locationService.currentLocation()
            userCoordinate = location.coordinate
            locationStatusMessage = "근처 정류장 조회 중 (TAGO 1613000)…"
            let results = try await client.nearbyStations(
                longitude: location.coordinate.longitude,
                latitude: location.coordinate.latitude
            )
            nearbyStations = results
            locationStatusMessage = "근처 \(results.count)개 · TAGO 1613000"
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

    private func selectRouteInternal(_ route: GbisRoute) async throws {
        selectedRoute = route
        selectedDestination = nil
        routeStations = try await client.stations(on: route.routeId)
        if let boarding = selectedStation,
           !routeStations.contains(where: { $0.stationId == boarding.stationId }) {
            // keep boarding from GPS even if not exact match list order
        }
        if routeStations.isEmpty { throw GbisAPIError.emptyResult }
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
