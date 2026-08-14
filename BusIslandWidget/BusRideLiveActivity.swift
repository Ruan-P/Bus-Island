import ActivityKit
import SwiftUI
import WidgetKit

private enum RideTheme {
    static let primary = Color(red: 0.18, green: 0.53, blue: 0.98) // Apple Blue (노선)
    static let accent = Color(red: 1.0, green: 0.58, blue: 0.0) // Warm Orange (하차 기본)
    static let boarding = Color(red: 0.20, green: 0.78, blue: 0.65) // Cool Teal (승차)
    static let destination = Color(red: 1.0, green: 0.32, blue: 0.32) // Alert Coral/Red (하차 1정거장 이하)
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
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(RideTheme.primary, in: Circle())

                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.routeNumber)
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Text(context.state.phaseTitle)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(context.state.isOnBoard ? RideTheme.accent : RideTheme.boarding)
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(context.state.activeRemainingStops)")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(activeCountColor(for: context.state))
                                .lineLimit(1)
                            Text("정거장")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        Text(context.state.isOnBoard ? "하차까지" : "승차까지")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(context.state.isOnBoard ? RideTheme.accent : RideTheme.boarding)
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // Dynamic Journey Progress Bar
                        journeyProgressBar(state: context.state)
                            .padding(.horizontal, 4)

                        // 2 Stop rows: 한 줄씩 승차 / 하차
                        stopRow(
                            role: "승차",
                            name: context.state.boarding,
                            count: context.state.boardingRemainingStops,
                            color: RideTheme.boarding,
                            isCurrentPhase: !context.state.isOnBoard
                        )

                        stopRow(
                            role: "하차",
                            name: context.state.destination,
                            count: context.state.remainingStops,
                            color: RideTheme.accent,
                            isCurrentPhase: context.state.isOnBoard
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .clipShape(ContainerRelativeShape())
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(RideTheme.primary)
                    Text(context.state.routeNumber)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                }
                .padding(.leading, 4)
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text(context.state.isOnBoard ? "하차" : "승차")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("\(context.state.activeRemainingStops)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(activeCountColor(for: context.state))
                        .lineLimit(1)
                }
                .padding(.trailing, 4)
            } minimal: {
                HStack(spacing: 1) {
                    Text("\(context.state.activeRemainingStops)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(activeCountColor(for: context.state))
                }
            }
            .keylineTint(context.state.isOnBoard ? RideTheme.accent : RideTheme.boarding)
        }
    }

    // MARK: - Dynamic Journey Progress Bar
    @ViewBuilder
    private func journeyProgressBar(state: BusRideActivityAttributes.ContentState) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(RideTheme.boarding)
                .frame(width: 6, height: 6)

            GeometryReader { geo in
                let totalWidth = geo.size.width
                let currentProgress = CGFloat(state.progress)
                let activeWidth = max(8, min(totalWidth, totalWidth * currentProgress))

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 4)

                    // Active filled bar
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: state.isOnBoard
                                    ? [RideTheme.boarding, RideTheme.accent]
                                    : [RideTheme.boarding.opacity(0.7), RideTheme.boarding],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: activeWidth, height: 4)

                    // Moving Bus Indicator Head
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, activeWidth - 4))
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 10)

            Circle()
                .fill(RideTheme.destination)
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - Stop Row (Expanded Bottom)
    @ViewBuilder
    private func stopRow(role: String, name: String, count: Int, color: Color, isCurrentPhase: Bool) -> some View {
        HStack(spacing: 8) {
            Text(role)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))

            Text(name.isEmpty ? "-" : name)
                .font(.system(size: 12, weight: isCurrentPhase ? .bold : .medium))
                .foregroundStyle(isCurrentPhase ? Color.white : Color.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(isCurrentPhase ? color : Color.white.opacity(0.4))
                Text("정거장")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isCurrentPhase ? Color.white.opacity(0.8) : Color.white.opacity(0.3))
            }
        }
    }

    // MARK: - Lock Screen Card UI
    @ViewBuilder
    private func lockScreenCard(state: BusRideActivityAttributes.ContentState) -> some View {
        VStack(spacing: 12) {
            // Header Row
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
                                .fill(state.isOnBoard ? Color.green : RideTheme.boarding)
                                .frame(width: 6, height: 6)
                            Text(state.isOnBoard ? "하차지 이동 중" : "승차 대기 중")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(state.activeRemainingStops)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(activeCountColor(for: state))
                        Text("정거장 남음")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text(state.isOnBoard ? "하차 정류장까지" : "승차 정류장까지")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(state.isOnBoard ? RideTheme.accent : RideTheme.boarding)
                }
            }

            // Realtime Progress Bar in Lock Screen
            journeyProgressBar(state: state)
                .padding(.horizontal, 2)

            Divider()
                .overlay(Color.white.opacity(0.12))

            // Station rows
            VStack(spacing: 6) {
                stopRow(
                    role: "승차",
                    name: state.boarding,
                    count: state.boardingRemainingStops,
                    color: RideTheme.boarding,
                    isCurrentPhase: !state.isOnBoard
                )

                stopRow(
                    role: "하차",
                    name: state.destination,
                    count: state.remainingStops,
                    color: RideTheme.accent,
                    isCurrentPhase: state.isOnBoard
                )
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
        .clipShape(ContainerRelativeShape())
        .activityBackgroundTint(Color.black.opacity(0.6))
        .activitySystemActionForegroundColor(.white)
    }

    private func activeCountColor(for state: BusRideActivityAttributes.ContentState) -> Color {
        if !state.isOnBoard {
            return state.boardingRemainingStops <= 1 ? RideTheme.destination : RideTheme.boarding
        } else {
            return state.remainingStops <= 1 ? RideTheme.destination : RideTheme.accent
        }
    }
}
