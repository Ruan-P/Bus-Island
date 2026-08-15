import CoreLocation
import Observation
import SwiftUI

// MARK: - Retro Pixel Palette & Tokens
enum RetroPixelTheme {
    static let teal = Color(red: 0.0, green: 0.78, blue: 0.78)       // 승차 / 출발 (Cyan-Teal)
    static let blue = Color(red: 0.20, green: 0.48, blue: 0.98)      // 노선 (Electric Arcade Blue)
    static let orange = Color(red: 1.0, green: 0.55, blue: 0.05)     // 하차 (Arcade Amber)
    static let green = Color(red: 0.18, green: 0.84, blue: 0.38)     // Live Active (Pixel Green)
    static let alertRed = Color(red: 1.0, green: 0.22, blue: 0.35)   // 하차 임박 (Pixel Alert Coral)
    static let purple = Color(red: 0.65, green: 0.35, blue: 0.95)    // 특수 액션
}

struct ContentView: View {
    @State private var viewModel = BusRideViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Pixel Header Status Bar
                    pixelTopStatusBar

                    // MARK: - Live Active Hero Card (When Tracking)
                    if viewModel.isActivityRunning {
                        activeTrackingHeroCard
                    }

                    // MARK: - Selected Journey Summary Card (승차 -> 노선 -> 하차)
                    journeySummaryCard

                    // MARK: - Step 1: Boarding Station Selection (정거장 우선)
                    boardingStationSectionCard

                    // MARK: - Step 2: Bus Arriving at this Station (이 정류장에 오는 버스)
                    if viewModel.selectedStation != nil {
                        arrivingBusesSectionCard
                    }

                    // MARK: - Step 3: Destination Selection (하차 정류장)
                    if viewModel.selectedStation != nil && viewModel.selectedRoute != nil {
                        destinationSectionCard
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
            .navigationTitle("BUSISLAND")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text("🚌")
                            .font(.system(size: 15))
                        Text("BUSISLAND")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .tracking(1.5)
                        Text("•")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(viewModel.isActivityRunning ? RetroPixelTheme.green : .secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("SET")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
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
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text("SYSTEM LOADING...")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .padding(22)
                        .background(Color(white: 0.15).opacity(0.95), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(RetroPixelTheme.teal.opacity(0.5), lineWidth: 1.5)
                        )
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

    // MARK: - Pixel Top Status Bar
    private var pixelTopStatusBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isActivityRunning ? RetroPixelTheme.green : Color.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                Text(viewModel.isActivityRunning ? "LIVE TRACKING ON" : "READY FOR MISSION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(viewModel.isActivityRunning ? RetroPixelTheme.green : .secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Text("ISLAND")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(RetroPixelTheme.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RetroPixelTheme.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                Text(viewModel.hasAPIKey ? "KEY:OK" : "KEY:OFF")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(viewModel.hasAPIKey ? RetroPixelTheme.teal : RetroPixelTheme.alertRed)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((viewModel.hasAPIKey ? RetroPixelTheme.teal : RetroPixelTheme.alertRed).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Active Tracking Hero Card (2-Phase Retro Cyber Arcade)
    private var activeTrackingHeroCard: some View {
        VStack(spacing: 14) {
            let isOnBoard = viewModel.snapshot?.isOnBoard ?? true

            // Arcade Status Tag & Bus Badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isOnBoard ? RetroPixelTheme.green : RetroPixelTheme.teal)
                            .frame(width: 8, height: 8)
                        Text(isOnBoard ? "■ PHASE: 하차지 이동 중" : "■ PHASE: 승차 대기 중")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(isOnBoard ? RetroPixelTheme.green : RetroPixelTheme.teal)
                    }

                    if let route = viewModel.selectedRoute {
                        HStack(spacing: 8) {
                            Text("BUS")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RetroPixelTheme.blue, in: RoundedRectangle(cornerRadius: 4))

                            Text(route.routeName)
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Spacer()

                // Retro Scoreboard Counter
                if let snapshot = viewModel.snapshot {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text(String(format: "%02d", snapshot.activeRemainingStops))
                                .font(.system(size: 32, weight: .black, design: .monospaced))
                                .foregroundStyle(
                                    isOnBoard
                                        ? (snapshot.remainingStops <= 1 ? RetroPixelTheme.alertRed : RetroPixelTheme.orange)
                                        : (snapshot.boardingRemainingStops <= 1 ? RetroPixelTheme.orange : RetroPixelTheme.teal)
                                )
                            Text("STOPS")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Text(isOnBoard ? "하차 정류장까지" : "승차 정류장까지")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(isOnBoard ? RetroPixelTheme.orange : RetroPixelTheme.teal)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                (isOnBoard ? (snapshot.remainingStops <= 1 ? RetroPixelTheme.alertRed : RetroPixelTheme.orange) : RetroPixelTheme.teal).opacity(0.35),
                                lineWidth: 1
                            )
                    )
                }
            }

            // Station Flow Route Pixel Path
            if let snapshot = viewModel.snapshot {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        // Boarding point
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("[출발]")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundStyle(RetroPixelTheme.teal)
                                Text("승차")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(RetroPixelTheme.teal)
                            }
                            Text(snapshot.boarding.isEmpty ? "-" : snapshot.boarding)
                                .font(.system(size: 13, weight: isOnBoard ? .medium : .bold))
                                .foregroundStyle(isOnBoard ? Color.secondary : Color.primary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Arrow
                        VStack(spacing: 2) {
                            Text("▶▶▶")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                        }

                        // Destination point
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("하차")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(RetroPixelTheme.orange)
                                Text("[도착]")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundStyle(RetroPixelTheme.orange)
                            }
                            Text(snapshot.destination.isEmpty ? "-" : snapshot.destination)
                                .font(.system(size: 13, weight: isOnBoard ? .bold : .medium))
                                .foregroundStyle(isOnBoard ? Color.primary : Color.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            // Quick Transition Action (When waiting to board)
            if !isOnBoard {
                Button {
                    Task { await viewModel.markAsBoarded() }
                } label: {
                    HStack(spacing: 8) {
                        Text("⚡")
                            .font(.system(size: 13))
                        Text("지금 버스 탑승함 [하차 알림 전환]")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(colors: [RetroPixelTheme.blue, Color(red: 0.1, green: 0.35, blue: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            HStack(spacing: 10) {
                Button {
                    Task { await viewModel.refreshNow() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                        Text("REFRESH")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(RetroPixelTheme.blue)
                    .background(RetroPixelTheme.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(RetroPixelTheme.blue.opacity(0.3), lineWidth: 1)
                    )
                }

                Button(role: .destructive) {
                    Task { await viewModel.endTracking() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.square.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("END MISSION")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(RetroPixelTheme.alertRed, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    (viewModel.snapshot?.isOnBoard ?? false ? RetroPixelTheme.green : RetroPixelTheme.teal).opacity(0.4),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    // MARK: - Journey Summary Card (승차 -> 노선 -> 하차)
    private var journeySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("◆")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(RetroPixelTheme.teal)
                    Text("MY JOURNEY")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text(viewModel.statusText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(viewModel.isActivityRunning ? RetroPixelTheme.green : .secondary)
            }

            // 칩 순서: 승차(Teal) -> 노선(Blue) -> 하차(Orange)
            HStack(spacing: 8) {
                journeyChip(
                    stepNumber: "01",
                    title: "승차",
                    value: viewModel.selectedStation?.stationName ?? "미선택",
                    icon: "figure.walk",
                    color: RetroPixelTheme.teal,
                    isSelected: viewModel.selectedStation != nil
                )

                journeyChip(
                    stepNumber: "02",
                    title: "노선",
                    value: viewModel.selectedRoute?.routeName ?? "미선택",
                    icon: "bus.fill",
                    color: RetroPixelTheme.blue,
                    isSelected: viewModel.selectedRoute != nil
                )

                journeyChip(
                    stepNumber: "03",
                    title: "하차",
                    value: viewModel.selectedDestination?.stationName ?? "미선택",
                    icon: "flag.checkered",
                    color: RetroPixelTheme.orange,
                    isSelected: viewModel.selectedDestination != nil
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func journeyChip(
        stepNumber: String,
        title: String,
        value: String,
        icon: String,
        color: Color,
        isSelected: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text("[\(stepNumber)]")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
            }
            .foregroundStyle(isSelected ? color : Color.secondary)

            Text(value)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: isSelected ? .monospaced : .default))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 32, alignment: .topLeading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? color.opacity(0.12) : Color(uiColor: .tertiarySystemFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 1: Boarding Station (정거장 우선)
    private var boardingStationSectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("[1]")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPixelTheme.teal)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RetroPixelTheme.teal.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    Text("승차 정류장")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                }
                Spacer()
                if let station = viewModel.selectedStation {
                    HStack(spacing: 4) {
                        Text("SELECTED:")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroPixelTheme.teal)
                        Text(station.stationName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RetroPixelTheme.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(RetroPixelTheme.teal.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            // GPS Quick Auto-select Nearest
            Button {
                Task {
                    await viewModel.loadNearbyStations()
                    viewModel.selectNearestBoarding()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("📍")
                        .font(.system(size: 14))
                    Text("내 위치 기준 가장 가까운 정류장 선택")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    Spacer()
                    Text("[AUTO]")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 4))
                }
                .padding(12)
                .foregroundStyle(.white)
                .background(RetroPixelTheme.teal, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            }

            // Map and Nearby List options
            HStack(spacing: 10) {
                NavigationLink {
                    NearbyStationsMapView(viewModel: viewModel)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(RetroPixelTheme.teal)
                        Text("지도에서 찾기")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
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
                        HStack(spacing: 6) {
                            Text("LIST")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(RetroPixelTheme.teal)
                            Text("근처 (\(viewModel.nearbyStations.count)개)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(RetroPixelTheme.teal.opacity(0.25), lineWidth: 1)
                        )
                    }
                }
            }

            // Station Name Search Input
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                    TextField("정류장 이름 검색 (예: 안양역, 사당역)", text: $viewModel.stationNameQuery)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .font(.system(size: 13, design: .monospaced))
                        .onSubmit { Task { await viewModel.searchStationsByName() } }
                    if !viewModel.stationNameQuery.isEmpty {
                        Button {
                            viewModel.stationNameQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

                Button {
                    Task { await viewModel.searchStationsByName() }
                } label: {
                    Text("SEARCH")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(RetroPixelTheme.teal)
                .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    HStack {
                        Text("검색 결과 [\(viewModel.stationNameResults.count)개 정류소]")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroPixelTheme.teal)
                        Spacer()
                        Text("VIEW ▶")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(RetroPixelTheme.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(RetroPixelTheme.teal.opacity(0.25), lineWidth: 1)
                    )
                }
            }

            if let message = viewModel.locationStatusMessage {
                Text("› \(message)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(viewModel.selectedStation != nil ? RetroPixelTheme.teal.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Step 2: Arriving Buses (이 정류장에 오는 버스)
    private var arrivingBusesSectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("[2]")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPixelTheme.blue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RetroPixelTheme.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    Text("탑승 버스 노선")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                }
                Spacer()
                if let route = viewModel.selectedRoute {
                    HStack(spacing: 4) {
                        Text("BUS:")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroPixelTheme.blue)
                        Text(route.routeName)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RetroPixelTheme.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(RetroPixelTheme.blue.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            // Arriving Bus List Picker
            if !viewModel.routeResults.isEmpty {
                NavigationLink {
                    RoutePickerView(
                        routes: viewModel.routeResults,
                        selectedID: viewModel.selectedRoute?.routeId
                    ) { route in
                        Task { await viewModel.selectRoute(route) }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("🚌")
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.selectedRoute?.routeName ?? "도착 예정 버스 (\(viewModel.routeResults.count)개) 중 선택")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundStyle(.primary)
                            Text("실시간 도착 정보 기반 노선 목록")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("SELECT ▶")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroPixelTheme.blue)
                    }
                    .padding(12)
                    .background(RetroPixelTheme.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(RetroPixelTheme.blue.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            // Supplementary Search: 번호로 직접 찾기
            DisclosureGroup {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "bus")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        TextField("노선 번호 입력 (예: 1-1, 3412)", text: $viewModel.routeQuery)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
                            .font(.system(size: 13, design: .monospaced))
                            .submitLabel(.search)
                            .onSubmit { Task { await viewModel.searchRoutes() } }
                        if !viewModel.routeQuery.isEmpty {
                            Button {
                                viewModel.routeQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                    Button {
                        Task { await viewModel.searchRoutes() }
                    } label: {
                        Text("FIND")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RetroPixelTheme.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(viewModel.routeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isBusy)
                }
                .padding(.top, 6)
            } label: {
                Text("노선 번호로 직접 찾기 (보조 검색)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(viewModel.selectedRoute != nil ? RetroPixelTheme.blue.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Step 3: Destination Selection (하차 정류장)
    private var destinationSectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("[3]")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPixelTheme.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RetroPixelTheme.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    Text("하차 정류장")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                }
                Spacer()
                if let dest = viewModel.selectedDestination {
                    HStack(spacing: 4) {
                        Text("DEST:")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroPixelTheme.orange)
                        Text(dest.stationName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RetroPixelTheme.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(RetroPixelTheme.orange.opacity(0.3), lineWidth: 1)
                    )
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
                HStack(spacing: 10) {
                    Text("🏁")
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.selectedDestination?.stationName ?? "하차할 정류장 선택하기")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(.primary)
                        Text("승차 이후 정류소 (\(viewModel.destinationCandidates.count)개 후보)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("CHOOSE ▶")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPixelTheme.orange)
                }
                .padding(12)
                .background(RetroPixelTheme.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(RetroPixelTheme.orange.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(viewModel.destinationCandidates.isEmpty)

            if viewModel.destinationCandidates.isEmpty {
                Text("› 승차 정류장 이후 운행하는 하차 정류장이 없습니다. 앞쪽 정류소를 선택해 보세요.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(viewModel.selectedDestination != nil ? RetroPixelTheme.orange.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Action Button Card
    private var actionButtonCard: some View {
        VStack(spacing: 8) {
            Button {
                Task { await viewModel.startTracking() }
            } label: {
                HStack(spacing: 8) {
                    Text("⚡")
                        .font(.system(size: 16))
                    Text("START DYNAMIC ISLAND")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(
                    viewModel.canStartTracking
                        ? AnyShapeStyle(LinearGradient(colors: [RetroPixelTheme.blue, Color(red: 0.05, green: 0.35, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.gray.opacity(0.35)),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(viewModel.canStartTracking ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
                .shadow(color: viewModel.canStartTracking ? RetroPixelTheme.blue.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
            }
            .disabled(!viewModel.canStartTracking || viewModel.isBusy)

            if !viewModel.canStartTracking {
                Text("› \(startGuideMessage)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 4)
    }

    private var startGuideMessage: String {
        if !viewModel.hasAPIKey { return "API 키가 등록되어 있지 않습니다. 설정에서 키를 확인하세요." }
        if !viewModel.activitiesEnabled { return "기기 설정에서 Live Activities를 허용해 주세요." }
        if viewModel.selectedStation == nil { return "1단계에서 승차 정류장을 선택해 주세요." }
        if viewModel.selectedRoute == nil { return "2단계에서 탑승할 버스를 선택해 주세요." }
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
    private let notifications = RideNotificationService.shared

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

    // Quick in-memory cache for station arriving routes [stationId: (savedAt, routes)]
    private var stationRoutesCache: [String: (savedAt: Date, routes: [GbisRoute])] = [:]

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
        if selectedRoute != nil { return "하차지 선택 대기" }
        if selectedStation != nil { return "버스 선택 대기" }
        return "승차 정류장 선택 필요"
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

    func selectNearbyStation(_ station: GbisStation) async {
        await run {
            AppLog.log("selectNearby \(station.stationName) id=\(station.stationId)")
            selectedStation = station
            selectedRoute = nil
            selectedDestination = nil
            routeStations = []

            // 1. 프리페치/캐시된 도착 노선 확인 (30초 TTL)
            let routes: [GbisRoute]
            if let cached = stationRoutesCache[station.stationId],
               Date().timeIntervalSince(cached.savedAt) < 30,
               !cached.routes.isEmpty {
                routes = cached.routes
                AppLog.log("selectNearby: using instant cached routes (\(routes.count))")
            } else {
                routes = try await client.routes(at: station.stationId)
                stationRoutesCache[station.stationId] = (Date(), routes)
            }

            routeResults = routes
            AppLog.log("selectNearby routes count=\(routes.count)")

            // 상위 도착 노선의 정류장 목록을 백그라운드에서 사전 로딩
            prefetchRouteStops(for: Array(routes.prefix(3)))

            if routes.count == 1 {
                try await selectRouteInternal(routes[0])
            }
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
        
        if !nearbyStations.isEmpty {
            let nearestStation = nearbyStations.min(by: { ($0.distanceMeters ?? Int.max) < ($1.distanceMeters ?? Int.max) })
            if let nearestStation {
                Task { await selectNearbyStation(nearestStation) }
                return
            }
        }

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

    func selectRoute(_ route: GbisRoute) async {
        await run {
            AppLog.log("selectRoute \(route.routeName) id=\(route.routeId)")
            selectedRoute = route
            selectedDestination = nil
            routeStations = try await client.stations(on: route.routeId)
            if let boarding = selectedStation,
               !routeStations.contains(where: { $0.stationId == boarding.stationId }) {
                // Keep GPS station if matching station sequence or ID exists
            }
            AppLog.log("selectRoute stations=\(routeStations.count) boardingKept=\(selectedStation != nil)")
            if routeStations.isEmpty { throw GbisAPIError.emptyResult }
        }
    }

    func selectDestination(_ stop: GbisRouteStation) {
        selectedDestination = stop
        if let station = selectedStation, let route = selectedRoute {
            let boardingSeq = routeStations.first(where: { $0.stationId == station.stationId })?.stationSeq ?? 0
            let diff = max(1, stop.stationSeq - boardingSeq)
            snapshot = BusRideSnapshot(
                id: "\(route.routeId)-\(station.stationId)-\(stop.stationId)",
                routeNumber: route.routeName,
                boarding: station.stationName,
                destination: stop.stationName,
                boardingRemainingStops: 0,
                remainingStops: diff,
                totalRideStops: diff
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

            // 상위 2개 근처 정류장의 도착 노선을 백그라운드에서 사전 조회
            prefetchNearbyRoutes(for: Array(results.prefix(2)))
        }
    }

    private func prefetchNearbyRoutes(for stations: [GbisStation]) {
        for station in stations {
            Task { [weak self] in
                guard let self else { return }
                if let cached = await self.stationRoutesCache[station.stationId],
                   Date().timeIntervalSince(cached.savedAt) < 30 {
                    return
                }
                if let routes = try? await self.client.routes(at: station.stationId) {
                    await MainActor.run {
                        self.stationRoutesCache[station.stationId] = (Date(), routes)
                    }
                    AppLog.log("prefetch: cached \(routes.count) routes for station \(station.stationName)")
                    self.prefetchRouteStops(for: Array(routes.prefix(2)))
                }
            }
        }
    }

    private func prefetchRouteStops(for routes: [GbisRoute]) {
        for route in routes {
            Task { [weak self] in
                guard let self else { return }
                _ = try? await self.client.stations(on: route.routeId)
            }
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
            await notifications.requestAuthorization()
            await locationService.startRideBackgroundUpdates()
            let initial = try await tracker.makeInitialSnapshot(from: selection)
            try await activityService.start(with: initial)
            snapshot = initial
            isActivityRunning = true
            tracker.startPolling(
                intervalSeconds: 15,
                onUpdate: { [weak self] updated in
                    guard let self else { return }
                    Task { @MainActor in
                        await self.applyRideUpdate(updated)
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
                try await activityService.update(
                    with: updated,
                    alertTitle: "승차함",
                    alertBody: "\(updated.destination)까지 하차 안내를 시작합니다."
                )
                snapshot = updated
            }
        }
    }

    func refreshNow() async {
        await run {
            let updated = try await tracker.refreshSnapshot()
            await applyRideUpdate(updated)
        }
    }

    private func applyRideUpdate(_ updated: BusRideSnapshot) async {
        do {
            let event = tracker.consumePhaseEvent()
            switch event {
            case .boardingSoon:
                notifications.notifyBoardingSoon(route: updated.routeNumber, station: updated.boarding)
                try await activityService.update(
                    with: updated,
                    alertTitle: "승차 1정거장",
                    alertBody: "\(updated.boarding)에서 승차한 뒤 앱에서 승차를 눌러 주세요."
                )
            case .boarded:
                try await activityService.update(
                    with: updated,
                    alertTitle: "승차 안내",
                    alertBody: "\(updated.destination)까지 하차 안내를 시작합니다."
                )
            case .alightSoon:
                notifications.notifyAlightSoon(route: updated.routeNumber, station: updated.destination)
                try await activityService.update(
                    with: updated,
                    alertTitle: "하차 1정거장",
                    alertBody: "다음 정류장은 \(updated.destination)입니다."
                )
            case .arrived:
                notifications.notifyArrived(route: updated.routeNumber, station: updated.destination)
                try await activityService.update(
                    with: updated,
                    alertTitle: "하차하세요",
                    alertBody: "\(updated.destination)에 도착했습니다."
                )
                snapshot = updated
                isActivityRunning = true
                try? await Task.sleep(for: .seconds(15))
                locationService.stopRideBackgroundUpdates()
                await activityService.end()
                tracker.reset()
                isActivityRunning = false
                return
            case .none:
                try await activityService.update(with: updated)
            }
            snapshot = updated
            isActivityRunning = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func endTracking() async {
        await run {
            notifications.clearRideNotifications()
            locationService.stopRideBackgroundUpdates()
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
