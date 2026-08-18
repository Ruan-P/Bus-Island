import ActivityKit
import SwiftUI
import WidgetKit

private enum RideTheme {
    static let primary = Color(red: 0.18, green: 0.53, blue: 0.98)       // Apple Electric Blue (노선)
    static let accent = Color(red: 1.0, green: 0.58, blue: 0.0)          // Warm Amber (하차 기본)
    static let boarding = Color(red: 0.15, green: 0.85, blue: 0.75)      // Electric Teal (승차)
    static let destination = Color(red: 1.0, green: 0.32, blue: 0.38)   // Alert Coral/Red (하차 1정거장 이하)
    static let liveGreen = Color(red: 0.18, green: 0.88, blue: 0.45)     // Live Beacon Green
}

struct BusRideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusRideActivityAttributes.self) { context in
            lockScreenCard(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 7) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(RideTheme.primary)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.routeNumber)
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Text(context.state.phaseTitle)
                                .font(.system(size: 10, weight: .bold))
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
                                .monospacedDigit()
                                .foregroundStyle(activeCountColor(for: context.state))
                                .lineLimit(1)
                            Text("정거장")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
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

                        // Station Rows with Live Passing Location
                        stopRow(
                            role: "승차",
                            name: context.state.boarding,
                            count: context.state.boardingRemainingStops,
                            currentLocation: !context.state.isOnBoard ? context.state.currentStation : nil,
                            color: RideTheme.boarding,
                            isCurrentPhase: !context.state.isOnBoard
                        )

                        stopRow(
                            role: "하차",
                            name: context.state.destination,
                            count: context.state.remainingStops,
                            currentLocation: context.state.isOnBoard ? context.state.currentStation : nil,
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
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.leading, 4)
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text(context.state.isOnBoard ? "하차" : "승차")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(context.state.activeRemainingStops)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(activeCountColor(for: context.state))
                        .lineLimit(1)
                }
                .padding(.trailing, 4)
            } minimal: {
                Text("\(context.state.activeRemainingStops)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(activeCountColor(for: context.state))
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
                    // Translucent track
                    Capsule()
                        .fill(Color.white.opacity(0.20))
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
                        .frame(width: 9, height: 9)
                        .offset(x: max(0, activeWidth - 4.5))
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 10)

            Circle()
                .fill(RideTheme.destination)
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - Stop Row (Clean & High-Contrast)
    @ViewBuilder
    private func stopRow(
        role: String,
        name: String,
        count: Int,
        currentLocation: String?,
        color: Color,
        isCurrentPhase: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Text(role)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(color)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(name.isEmpty ? "-" : name)
                    .font(.system(size: 14, weight: isCurrentPhase ? .heavy : .semibold))
                    .foregroundStyle(isCurrentPhase ? Color.white : Color.white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if isCurrentPhase, let loc = currentLocation, !loc.isEmpty, loc != name {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("현재 위치: \(loc)")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundStyle(color)
                    .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isCurrentPhase ? color : Color.white.opacity(0.40))
                Text("정거장")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(isCurrentPhase ? Color.white.opacity(0.90) : Color.white.opacity(0.35))
            }
        }
    }

    // MARK: - Lock Screen Card UI (iOS 26 Liquid Glass)
    @ViewBuilder
    private func lockScreenCard(state: BusRideActivityAttributes.ContentState) -> some View {
        GlassEffectContainer {
            VStack(spacing: 12) {
                // Header Row: Bus Badge + Active Tracking Phase & Scoreboard Countdown
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(7)
                            .rideLiquidGlass(in: Circle(), tint: RideTheme.primary.opacity(0.35))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(state.routeNumber)
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(.primary)
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(state.isOnBoard ? RideTheme.liveGreen : RideTheme.boarding)
                                    .frame(width: 6, height: 6)
                                Text(state.isOnBoard ? "하차지 이동 중 · LIVE" : "승차 대기 중 · LIVE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(state.isOnBoard ? RideTheme.liveGreen : RideTheme.boarding)
                            }
                        }
                    }

                    Spacer()

                    // Large Vivid Scoreboard Countdown
                    VStack(alignment: .trailing, spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(state.activeRemainingStops)")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(activeCountColor(for: state))
                            Text(state.isOnBoard ? "정거장 남음" : "정거장 전")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(.secondary)
                        }
                        Text(state.isOnBoard ? "목표 하차지까지" : "승차 정류소까지")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(state.isOnBoard ? RideTheme.accent : RideTheme.boarding)
                    }
                }

                // Realtime Progress Bar in Lock Screen
                journeyProgressBar(state: state)
                    .padding(.horizontal, 2)

                Divider()

                // Station rows: 승차 / 하차
                VStack(spacing: 7) {
                    lockScreenStopRow(
                        role: "승차",
                        name: state.boarding,
                        count: state.boardingRemainingStops,
                        currentLocation: !state.isOnBoard ? state.currentStation : nil,
                        color: RideTheme.boarding,
                        isCurrentPhase: !state.isOnBoard
                    )

                    lockScreenStopRow(
                        role: "하차",
                        name: state.destination,
                        count: state.remainingStops,
                        currentLocation: state.isOnBoard ? state.currentStation : nil,
                        color: RideTheme.accent,
                        isCurrentPhase: state.isOnBoard
                    )
                }
            }
            .padding(16)
        }
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.white)
    }

    // MARK: - Lock Screen Stop Row (Liquid Glass badge)
    @ViewBuilder
    private func lockScreenStopRow(
        role: String,
        name: String,
        count: Int,
        currentLocation: String?,
        color: Color,
        isCurrentPhase: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Text(role)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .rideLiquidGlass(in: .rect(cornerRadius: 6, style: .continuous), tint: color.opacity(0.3))

            VStack(alignment: .leading, spacing: 1.5) {
                Text(name.isEmpty ? "-" : name)
                    .font(.system(size: 14, weight: isCurrentPhase ? .heavy : .semibold))
                    .foregroundStyle(isCurrentPhase ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if isCurrentPhase, let loc = currentLocation, !loc.isEmpty, loc != name {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("현재 위치: \(loc)")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundStyle(color)
                    .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isCurrentPhase ? AnyShapeStyle(color) : AnyShapeStyle(.tertiary))
                Text("정거장")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(isCurrentPhase ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
            }
        }
    }

    private func activeCountColor(for state: BusRideActivityAttributes.ContentState) -> Color {
        if !state.isOnBoard {
            return state.boardingRemainingStops <= 1 ? RideTheme.destination : RideTheme.boarding
        } else {
            return state.remainingStops <= 1 ? RideTheme.destination : RideTheme.accent
        }
    }
}
