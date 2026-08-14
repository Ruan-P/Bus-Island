import ActivityKit
import SwiftUI
import WidgetKit

private enum RideTheme {
    static let primary = Color(red: 0.18, green: 0.53, blue: 0.98) // Apple Blue
    static let accent = Color(red: 1.0, green: 0.58, blue: 0.0) // Warm Orange
    static let boarding = Color(red: 0.20, green: 0.78, blue: 0.65) // Mint Teal
    static let destination = Color(red: 1.0, green: 0.32, blue: 0.32) // Soft Coral
    static let darkSurface = Color(white: 0.12)
}

struct BusRideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusRideActivityAttributes.self) { context in
            lockScreenCard(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(RideTheme.primary, in: Circle())

                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.routeNumber)
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("실시간 안내")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(context.state.remainingStops)")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(context.state.remainingStops <= 1 ? RideTheme.destination : RideTheme.accent)
                            Text("정거장")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        if context.state.remainingStops <= 1 {
                            Text("🔔 곧 하차")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(RideTheme.destination)
                        } else {
                            Text("이동 중")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        // Progress bar connecting boarding & destination
                        HStack(spacing: 8) {
                            Circle()
                                .fill(RideTheme.boarding)
                                .frame(width: 8, height: 8)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.18))
                                        .frame(height: 4)

                                    let total = max(1, context.state.remainingStops + context.state.boardingRemainingStops)
                                    let progress = 1.0 - (Double(context.state.remainingStops) / Double(total))
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [RideTheme.boarding, RideTheme.accent],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(12, geo.size.width * CGFloat(min(1.0, max(0.05, progress)))), height: 4)
                                }
                                .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .frame(height: 12)

                            Circle()
                                .fill(RideTheme.destination)
                                .frame(width: 8, height: 8)
                        }
                        .padding(.horizontal, 4)

                        // Station Names
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("승차")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(RideTheme.boarding)
                                Text(context.state.boarding.isEmpty ? "출발지" : context.state.boarding)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("하차")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(RideTheme.destination)
                                Text(context.state.destination.isEmpty ? "도착지" : context.state.destination)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(RideTheme.primary)
                    Text(context.state.routeNumber)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                }
                .padding(.leading, 4)
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text("\(context.state.remainingStops)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(context.state.remainingStops <= 1 ? RideTheme.destination : RideTheme.accent)
                    Text("정거장")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 4)
            } minimal: {
                HStack(spacing: 1) {
                    Text("\(context.state.remainingStops)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(context.state.remainingStops <= 1 ? RideTheme.destination : RideTheme.accent)
                }
            }
            .keylineTint(RideTheme.accent)
        }
    }

    // MARK: - Lock Screen / Banner Card UI
    @ViewBuilder
    private func lockScreenCard(state: BusRideActivityAttributes.ContentState) -> some View {
        VStack(spacing: 12) {
            // Header Row: Bus Badge + Live status + Remaining Stops
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(RideTheme.primary, in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(state.routeNumber)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("실시간 하차 알림")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(state.remainingStops)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(state.remainingStops <= 1 ? RideTheme.destination : RideTheme.accent)
                        Text("정거장 남음")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    if state.remainingStops <= 1 {
                        Text("🔔 곧 하차 준비를 하세요")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RideTheme.destination)
                    }
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.12))

            // Route Progress & Stations
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(RideTheme.boarding)
                        .frame(width: 8, height: 8)

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 5)

                        let total = max(1, state.remainingStops + state.boardingRemainingStops)
                        let progress = 1.0 - (Double(state.remainingStops) / Double(total))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [RideTheme.boarding, RideTheme.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(20, CGFloat(progress) * 200), height: 5)
                    }

                    Circle()
                        .fill(RideTheme.destination)
                        .frame(width: 8, height: 8)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("승차")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RideTheme.boarding)
                        Text(state.boarding.isEmpty ? "출발 정류장" : state.boarding)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("하차 (목적지)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RideTheme.destination)
                        Text(state.destination.isEmpty ? "도착 정류장" : state.destination)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(white: 0.15), Color(white: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .activityBackgroundTint(Color.black.opacity(0.6))
        .activitySystemActionForegroundColor(.white)
    }
}
