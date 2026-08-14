import CoreLocation
import Observation
import SwiftUI

struct ContentView: View {
    @State private var viewModel = BusRideViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // MARK: - Live Active Hero Card (When Tracking)
                    if viewModel.isActivityRunning {
                        activeTrackingHeroCard
                    }

                    // MARK: - Selected Route & Stations Journey Summary Card
                    journeySummaryCard

                    // MARK: - Step 1: Bus Route Selection
                    routeSelectionCard

                    // MARK: - Step 2: Boarding Stop Selection
                    if viewModel.selectedRoute != nil {
                        boardingSelectionCard
                    }

                    // MARK: - Step 3: Alighting Stop Selection
                    if viewModel.selectedRoute != nil && viewModel.selectedStation != nil {
                        destinationSelectionCard
                    }

                    // MARK: - Action Section (Start Live Activity)
                    if !viewModel.isActivityRunning {
                        actionButtonCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("BusIsland")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .alert("안내", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .overlay {
                if viewModel.isBusy {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text("정보를 불러오는 중...")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.white)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .task { viewModel.refreshStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { viewModel.refreshStatus() }
            }
            .onAppear { viewModel.refreshStatus() }
        }
    }

    // MARK: - Active Tracking Hero Card (2-Phase)
    private var activeTrackingHeroCard: some View {
        VStack(spacing: 16) {
            let isOnBoard = viewModel.snapshot?.isOnBoard ?? true

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isOnBoard ? Color.green : Color.teal)
                            .frame(width: 8, height: 8)
                        Text(isOnBoard ? "하차지 이동 중 · Island 활성" : "승차 대기 중 · Island 활성")
                            .font(.caption.bold())
                            .foregroundStyle(isOnBoard ? Color.green : Color.teal)
                    }

                    if let route = viewModel.selectedRoute {
                        HStack(spacing: 6) {
                            Image(systemName: "bus.fill")
                                .font(.title3)
                                .foregroundStyle(isOnBoard ? .blue : .teal)
                            Text(route.routeName)
                                .font(.system(size: 24, weight: .black, design: .rounded))
                        }
                    }
                }

                Spacer()

                if let snapshot = viewModel.snapshot {
                    VStack(alignment: .trailing, spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(snapshot.activeRemainingStops)")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    isOnBoard
                                        ? (snapshot.remainingStops <= 1 ? Color.red : Color.orange)
                                        : (snapshot.boardingRemainingStops <= 1 ? Color.orange : Color.teal)
                                )
                            Text(isOnBoard ? "정거장 남음" : "정거장 전")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        Text(isOnBoard ? "하차 정류장까지" : "승차 정류장까지")
                            .font(.caption2.bold())
                            .foregroundStyle(isOnBoard ? Color.orange : Color.teal)
                    }
                }
            }

            if let snapshot = viewModel.snapshot {
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("승차 (출발)")
                                .font(.caption2.bold())
                                .foregroundStyle(.teal)
                            Text(snapshot.boarding.isEmpty ? "-" : snapshot.boarding)
                                .font(.subheadline.weight(isOnBoard ? .regular : .bold))
                                .foregroundStyle(isOnBoard ? Color.secondary : Color.primary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("하차 (도착)")
                                .font(.caption2.bold())
                                .foregroundStyle(.orange)
                            Text(snapshot.destination.isEmpty ? "-" : snapshot.destination)
                                .font(.subheadline.weight(isOnBoard ? .bold : .regular))
                                .foregroundStyle(isOnBoard ? Color.primary : Color.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            // Quick Transition Action (When waiting to board)
            if !isOnBoard {
                Button {
                    Task { await viewModel.markAsBoarded() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk.arrival")
                        Text("지금 버스에 탑승함 (하차 알림으로 전환)")
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.refreshNow() }
                } label: {
                    Label("지금 갱신", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button(role: .destructive) {
                    Task { await viewModel.endTracking() }
                } label: {
                    Label("알림 종료", systemImage: "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - Journey Summary Card
    private var journeySummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("나의 여정")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(viewModel.statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(viewModel.isActivityRunning ? Color.green : Color.secondary)
            }

            HStack(spacing: 8) {
                journeyChip(
                    title: "노선",
                    value: viewModel.selectedRoute?.routeName ?? "선택 필요",
                    icon: "bus.fill",
                    color: .blue,
                    isSelected: viewModel.selectedRoute != nil
                )

                journeyChip(
                    title: "승차",
                    value: viewModel.selectedStation?.stationName ?? "선택 필요",
                    icon: "figure.walk",
                    color: .teal,
                    isSelected: viewModel.selectedStation != nil
                )

                journeyChip(
                    title: "하차",
                    value: viewModel.selectedDestination?.stationName ?? "선택 필요",
                    icon: "flag.checkered",
                    color: .orange,
                    isSelected: viewModel.selectedDestination != nil
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    private func journeyChip(
        title: String,
        value: String,
        icon: String,
        color: Color,
        isSelected: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(isSelected ? color : Color.secondary)

            Text(value)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 34, alignment: .topLeading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? color.opacity(0.12) : Color(uiColor: .tertiarySystemFill))
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 1: Route Selection Card
    private var routeSelectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("1. 노선 검색 및 선택", systemImage: "magnifyingglass")
                    .font(.headline)
                Spacer()
                if let route = viewModel.selectedRoute {
                    Text(route.routeName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                }
            }

            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "bus")
                        .foregroundStyle(.secondary)
                    TextField("노선 번호 입력 (예: 1-1, 3412)", text: $viewModel.routeQuery)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.numbersAndPunctuation)
                        .submitLabel(.search)
                        .onSubmit { Task { await viewModel.searchRoutes() } }
                    if !viewModel.routeQuery.isEmpty {
                        Button {
                            viewModel.routeQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

                Button {
                    Task { await viewModel.searchRoutes() }
                } label: {
                    Text("검색")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
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
                    HStack {
                        Image(systemName: "list.bullet.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("검색된 노선 목록 (\(viewModel.routeResults.count)개)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("목록에서 정확한 노선을 선택하세요")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Step 2: Boarding Stop Card
    private var boardingSelectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("2. 승차 정류장 선택", systemImage: "figure.walk")
                    .font(.headline)
                Spacer()
                if let station = viewModel.selectedStation {
                    Text(station.stationName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.teal.opacity(0.15), in: Capsule())
                        .foregroundStyle(.teal)
                }
            }

            // GPS Quick Nearest Action
            if viewModel.userCoordinate != nil {
                Button {
                    viewModel.selectNearestBoarding()
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.system(size: 15))
                        Text("내 위치에서 가장 가까운 정류장 자동 선택")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "sparkles")
                    }
                    .padding(12)
                    .foregroundStyle(.white)
                    .background(Color.teal, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            // Quick Actions: Map & Route Stop List
            HStack(spacing: 10) {
                NavigationLink {
                    NearbyStationsMapView(viewModel: viewModel)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                            .foregroundStyle(.teal)
                        Text("지도에서 찾기")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                }

                NavigationLink {
                    StopPickerView(
                        title: "승차 정류장 선택",
                        roleLabel: "노선 내 정류장",
                        stops: viewModel.routeStations,
                        selectedID: viewModel.selectedStation?.stationId
                    ) { stop in
                        viewModel.selectBoardingStop(stop)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.number")
                            .foregroundStyle(.teal)
                        Text("노선 전체 목록 (\(viewModel.routeStations.count))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.routeStations.isEmpty)
            }

            if let message = viewModel.locationStatusMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Step 3: Destination Card
    private var destinationSelectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("3. 하차 정류장 선택", systemImage: "flag.checkered")
                    .font(.headline)
                Spacer()
                if let dest = viewModel.selectedDestination {
                    Text(dest.stationName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }

            NavigationLink {
                StopPickerView(
                    title: "하차 정류장 선택",
                    roleLabel: "하차 가능 정류장",
                    stops: viewModel.destinationCandidates,
                    selectedID: viewModel.selectedDestination?.id
                ) { stop in
                    viewModel.selectDestination(stop)
                }
            } label: {
                HStack {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.selectedDestination?.stationName ?? "하차할 정류장 선택하기")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("승차 이후 정류장 \(viewModel.destinationCandidates.count)개 중 선택")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.destinationCandidates.isEmpty)

            if viewModel.destinationCandidates.isEmpty {
                Text("승차 정류장 이후에 운행하는 하차 정류장이 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Action Button Card
    private var actionButtonCard: some View {
        VStack(spacing: 8) {
            Button {
                Task { await viewModel.startTracking() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.headline)
                    Text("Dynamic Island 알림 시작")
                        .font(.headline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(
                    viewModel.canStartTracking
                        ? AnyShapeStyle(LinearGradient(colors: [.blue, Color(red: 0.1, green: 0.4, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.gray.opacity(0.4)),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .disabled(!viewModel.canStartTracking || viewModel.isBusy)

            if !viewModel.canStartTracking {
                Text(startGuideMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 6)
    }

    private var startGuideMessage: String {
        if !viewModel.hasAPIKey { return "API 키가 등록되어 있지 않습니다. 설정에서 키를 확인하세요." }
        if !viewModel.activitiesEnabled { return "기기 설정에서 Live Activities를 허용해 주세요." }
        if viewModel.selectedRoute == nil { return "1단계에서 노선을 검색하여 선택해 주세요." }
        if viewModel.selectedStation == nil { return "2단계에서 승차 정류장을 선택해 주세요." }
        if viewModel.selectedDestination == nil { return "3단계에서 하차 정류장을 선택해 주세요." }
        return "알림을 시작할 준비가 되었습니다."
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
        keyStore.isUsingBakedDefault ? "API 키: 기본키" : "API 키: 사용자 저장키"
    }

    var statusText: String {
        if !hasAPIKey { return "인증키 필요" }
        if !activitiesEnabled { return "Live Activities 꺼짐" }
        if isActivityRunning {
            if let snapshot {
                return snapshot.isOnBoard
                    ? "하차까지 \(snapshot.remainingStops)정거장"
                    : "승차까지 \(snapshot.boardingRemainingStops)정거장"
            }
            return "실시간 안내 중"
        }
        if selectedDestination != nil { return "시작 준비 완료" }
        if selectedStation != nil { return "하차지 선택 대기" }
        if selectedRoute != nil { return "승차지 선택 대기" }
        return "노선 검색 필요"
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
            locationStatusMessage = "선택됨: \(nearest.0.stationName) (\(nearest.1)m)"
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
            locationStatusMessage = "위치 권한 확인 중..."
            _ = try await locationService.ensureWhenInUseAuthorization()
            locationStatusMessage = locationService.isAuthorized
                ? "위치 권한 허용됨"
                : "위치 권한 필요"
        }
    }

    func loadNearbyStations() async {
        await run {
            locationStatusMessage = "내 위치 파악 중..."
            let location = try await locationService.currentLocation()
            userCoordinate = location.coordinate
            locationStatusMessage = "근처 정류장 검색 중..."
            let results = try await client.nearbyStations(
                longitude: location.coordinate.longitude,
                latitude: location.coordinate.latitude
            )
            nearbyStations = results
            locationStatusMessage = "근처 \(results.count)개 정류장 발견"
            AppLog.log("nearby loaded \(results.count) first=\(results.first.map { "\($0.stationName)/\($0.stationId)" } ?? "-")")
        }
    }

    func startTracking() async {
        guard let station = selectedStation,
              let route = selectedRoute,
              let destination = selectedDestination
        else { return }

        await run {
            let boardingSeq = routeStations.first(where: { $0.stationId == station.stationId })?.stationSeq ?? 0
            let selection = GbisRideSelection(
                boardingStation: station,
                route: route,
                destination: destination,
                boardingSeq: boardingSeq
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

    func markAsBoarded() async {
        await run {
            if let updated = tracker.markAsBoarded() {
                try await activityService.update(with: updated)
                snapshot = updated
            }
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
