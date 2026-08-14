import CoreLocation
import Observation
import SwiftUI

struct ContentView: View {
    @State private var viewModel = BusRideViewModel()
    @State private var debugLog = DebugLogStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BI-GBIS v1.1 build 17")
                            .font(.title2.bold())
                        Text(viewModel.keyStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("API 키 설정", systemImage: "key.fill")
                    }

                    NavigationLink {
                        DebugConsoleView()
                    } label: {
                        Label("디버그 콘솔 (\(debugLog.lines.count))", systemImage: "text.alignleft")
                    }
                }

                statusSection
                tripSummarySection
                findBoardingSection
                routeSection
                if viewModel.selectedRoute != nil {
                    boardingPickSection
                }
                if viewModel.selectedStation != nil, viewModel.selectedRoute != nil {
                    alightingPickSection
                }
                rideSection
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

    private var tripSummarySection: some View {
        Section {
            HStack(spacing: 10) {
                tripChip(
                    title: "노선",
                    value: viewModel.selectedRoute?.routeName ?? "미선택",
                    systemImage: "bus.fill",
                    tint: .indigo
                )
                tripChip(
                    title: "승차",
                    value: viewModel.selectedStation?.stationName ?? "미선택",
                    count: viewModel.snapshot?.boardingRemainingStops,
                    systemImage: "figure.walk",
                    tint: .cyan
                )
                tripChip(
                    title: "하차",
                    value: viewModel.selectedDestination?.stationName ?? "미선택",
                    count: viewModel.snapshot?.remainingStops,
                    systemImage: "flag.fill",
                    tint: .orange
                )
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            .listRowBackground(Color.clear)
        } header: {
            Text("이번 탑승")
        }
    }

    private func tripChip(
        title: String,
        value: String,
        count: Int? = nil,
        systemImage: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
                Spacer(minLength: 0)
                if let count {
                    Text("\(count)")
                        .font(.headline.bold().monospacedDigit())
                }
            }
            .font(.caption.weight(.semibold))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(tint)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var findBoardingSection: some View {
        Section {
            Button {
                Task { await viewModel.loadNearbyStations() }
            } label: {
                Label("GPS로 근처 승차 정류장 찾기", systemImage: "location.fill")
            }
            .disabled(viewModel.isBusy)

            NavigationLink {
                NearbyStationsMapView(viewModel: viewModel)
            } label: {
                Label("지도에서 승차 고르기", systemImage: "map.fill")
            }

            if !viewModel.nearbyStations.isEmpty {
                NavigationLink {
                    NearbyStationPickerView(
                        stations: viewModel.nearbyStations,
                        selectedID: viewModel.selectedStation?.stationId
                    ) { station in
                        Task { await viewModel.selectNearbyStation(station) }
                    }
                } label: {
                    Label("근처 \(viewModel.nearbyStations.count)개에서 검색해 고르기", systemImage: "magnifyingglass")
                }
            }

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

            if !viewModel.stationNameResults.isEmpty {
                NavigationLink {
                    NearbyStationPickerView(
                        stations: viewModel.stationNameResults,
                        selectedID: viewModel.selectedStation?.stationId
                    ) { station in
                        Task { await viewModel.selectNearbyStation(station) }
                    }
                } label: {
                    Label("이름 검색 \(viewModel.stationNameResults.count)개에서 고르기", systemImage: "text.magnifyingglass")
                }
            }
        } header: {
            Text("1. 승차 정류장 찾기")
        } footer: {
            Text(viewModel.locationStatusMessage ?? "근처 목록은 검색 화면에서 고릅니다.")
        }
    }

    private var routeSection: some View {
        Section {
            HStack {
                TextField("노선 번호 (예: 1-1, 8)", text: $viewModel.routeQuery)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.search)
                    .onSubmit { Task { await viewModel.searchRoutes() } }
                Button("검색") {
                    Task { await viewModel.searchRoutes() }
                }
                .disabled(viewModel.routeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isBusy)
            }

            if !viewModel.routeResults.isEmpty {
                NavigationLink {
                    RoutePickerView(
                        routes: viewModel.routeResults,
                        selectedID: viewModel.selectedRoute?.routeId
                    ) { route in
                        Task { await viewModel.selectRoute(route) }
                    }
                } label: {
                    Label("노선 \(viewModel.routeResults.count)개에서 검색해 고르기", systemImage: "bus")
                }
            }
        } header: {
            Text("2. 노선")
        }
    }

    private var boardingPickSection: some View {
        Section {
            if viewModel.userCoordinate != nil {
                Button {
                    viewModel.selectNearestBoarding()
                } label: {
                    Label("가장 가까운 정류장을 승차로", systemImage: "location.north.circle.fill")
                }
            }

            NavigationLink {
                StopPickerView(
                    title: "승차 정류장",
                    roleLabel: "승차",
                    stops: viewModel.routeStations,
                    selectedID: viewModel.selectedStation?.stationId
                ) { stop in
                    viewModel.selectBoardingStop(stop)
                }
            } label: {
                Label("노선 정류장 \(viewModel.routeStations.count)개에서 승차 고르기", systemImage: "figure.walk")
            }
            .disabled(viewModel.routeStations.isEmpty)
        } header: {
            Text("3. 승차")
        }
    }

    private var alightingPickSection: some View {
        Section {
            NavigationLink {
                StopPickerView(
                    title: "하차 정류장",
                    roleLabel: "하차",
                    stops: viewModel.destinationCandidates,
                    selectedID: viewModel.selectedDestination?.id
                ) { stop in
                    viewModel.selectDestination(stop)
                }
            } label: {
                Label("이후 정류장 \(viewModel.destinationCandidates.count)개에서 하차 고르기", systemImage: "flag.fill")
            }
            .disabled(viewModel.destinationCandidates.isEmpty)

            if viewModel.destinationCandidates.isEmpty {
                Text("승차 이후 하차 정류장이 없습니다. 승차를 앞쪽으로 바꿔 보세요.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("4. 하차")
        }
    }

    private var rideSection: some View {
        Section("알림") {
            if let snapshot = viewModel.snapshot {
                LabeledContent("노선", value: snapshot.routeNumber)
                LabeledContent("승차까지", value: "\(snapshot.boardingRemainingStops)정거장")
                LabeledContent("하차까지", value: "\(snapshot.remainingStops)정거장")
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
        if selectedStation != nil { return "하차 정류장을 고르세요" }
        if selectedRoute != nil { return "승차 정류장을 고르세요" }
        return "승차 정류장 또는 노선을 찾으세요"
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
            AppLog.log("selectRoute \(route.routeName) id=\(route.routeId)")
            selectedRoute = route
            selectedDestination = nil
            // Keep boarding if it exists on this route; else clear.
            routeStations = try await client.stations(on: route.routeId)
            if let boarding = selectedStation,
               !routeStations.contains(where: { $0.stationId == boarding.stationId }) {
                selectedStation = nil
            }
            AppLog.log("selectRoute stations=\(routeStations.count) boardingKept=\(selectedStation != nil)")
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
            AppLog.log("selectNearby \(station.stationName) id=\(station.stationId) region=\(station.regionName ?? "-")")
            selectedStation = station
            selectedRoute = nil
            selectedDestination = nil
            routeStations = []
            let routes = try await client.routes(at: station.stationId)
            routeResults = routes
            AppLog.log("selectNearby routes=\(routes.map(\.routeName).joined(separator: ","))")
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
                boarding: station.stationName,
                destination: stop.stationName,
                boardingRemainingStops: 0,
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
            AppLog.log("nearby loaded \(results.count) first=\(results.first.map { "\($0.stationName)/\($0.stationId)" } ?? "-")")
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
            AppLog.log("ERROR \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
