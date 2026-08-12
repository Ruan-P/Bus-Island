import Observation
import SwiftUI

struct ContentView: View {
    @State private var viewModel = BusRideDemoViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                rideCard
                statusBanner
                actionButtons
                Spacer()
            }
            .padding()
            .navigationTitle("BusIsland")
            .alert("오류", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task { await viewModel.refresh() }
        }
    }

    private var rideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("테스트 버스 라이드", systemImage: "bus.fill")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("노선")
                        .foregroundStyle(.secondary)
                    Text(viewModel.snapshot.routeNumber)
                        .font(.title2.bold())
                        .monospacedDigit()
                }
                GridRow {
                    Text("목적지")
                        .foregroundStyle(.secondary)
                    Text(viewModel.snapshot.destination)
                        .font(.title3.weight(.semibold))
                }
                GridRow {
                    Text("남은 정거장")
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.snapshot.remainingStops)")
                        .font(.title2.bold())
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusBanner: some View {
        HStack {
            Circle()
                .fill(viewModel.isActivityRunning ? Color.green : Color.secondary)
                .frame(width: 10, height: 10)
            Text(viewModel.statusText)
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await viewModel.startLiveActivity() }
            } label: {
                Label("Live Activity 시작", systemImage: "dot.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isBusy)

            Button {
                Task { await viewModel.decrementStops() }
            } label: {
                Label("남은 정거장 -1", systemImage: "minus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isBusy || !viewModel.isActivityRunning)

            Button {
                Task { await viewModel.resetPrototype() }
            } label: {
                Label("프로토타입 데이터 리셋", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isBusy)

            Button(role: .destructive) {
                Task { await viewModel.endLiveActivity() }
            } label: {
                Label("Live Activity 종료", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isBusy || !viewModel.isActivityRunning)
        }
        .padding(.horizontal)
    }
}

@MainActor
@Observable
final class BusRideDemoViewModel {
    private let rideService: MockBusRideService
    private let activityService: LiveActivityService

    var snapshot: BusRideSnapshot = .prototype
    var isActivityRunning = false
    var isBusy = false
    var errorMessage: String?
    var activitiesEnabled = true

    init(
        rideService: MockBusRideService = MockBusRideService(),
        activityService: LiveActivityService = LiveActivityService()
    ) {
        self.rideService = rideService
        self.activityService = activityService
    }

    var statusText: String {
        if !activitiesEnabled {
            return "이 기기에서 Live Activities가 비활성화되어 있습니다. (설정 확인)"
        }
        return isActivityRunning
            ? "Dynamic Island / 잠금 화면에 Live Activity 표시 중"
            : "Live Activity 대기 중 — 시작 버튼을 누르세요"
    }

    func refresh() async {
        snapshot = await rideService.currentRide()
        activitiesEnabled = activityService.areActivitiesEnabled
        isActivityRunning = activityService.hasActiveActivity
    }

    func startLiveActivity() async {
        await run {
            let ride = await rideService.currentRide()
            try activityService.start(with: ride)
            snapshot = ride
            isActivityRunning = true
        }
    }

    func decrementStops() async {
        await run {
            let ride = await rideService.decrementRemainingStops()
            try await activityService.update(with: ride)
            snapshot = ride
            isActivityRunning = true
        }
    }

    func resetPrototype() async {
        await run {
            let ride = await rideService.resetToPrototype()
            snapshot = ride
            if activityService.hasActiveActivity {
                try await activityService.update(with: ride)
                isActivityRunning = true
            }
        }
    }

    func endLiveActivity() async {
        await run {
            await activityService.end()
            isActivityRunning = false
        }
    }

    private func run(_ work: () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await work()
            activitiesEnabled = activityService.areActivitiesEnabled
        } catch {
            errorMessage = error.localizedDescription
            isActivityRunning = activityService.hasActiveActivity
        }
    }
}

#Preview {
    ContentView()
}
