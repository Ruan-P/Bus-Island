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
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(RideTheme.primary, in: Circle())
                            .shadow(color: RideTheme.primary.opacity(0.5), radius: 3)

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
                .shadow(color: RideTheme.boarding.opacity(0.8), radius: 3)

            GeometryReader { geo in
                let totalWidth = geo.size.width
                let currentProgress = CGFloat(state.progress)
                let activeWidth = max(8, min(totalWidth, totalWidth * currentProgress))

                ZStack(alignment: .leading) {
                    // Translucent track
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 4)

                    // Active glowing filled bar
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
                        .shadow(color: (state.isOnBoard ? RideTheme.accent : RideTheme.boarding).opacity(0.5), radius: 3)

                    // Moving Bus Indicator Head
                    Circle()
                        .fill(Color.white)
                        .frame(width: 9, height: 9)
                        .shadow(color: Color.black.opacity(0.6), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, activeWidth - 4.5))
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 10)

            Circle()
                .fill(RideTheme.destination)
                .frame(width: 6, height: 6)
                .shadow(color: RideTheme.destination.opacity(0.8), radius: 3)
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
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.20), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(color.opacity(0.40), lineWidth: 0.75)
                )

            VStack(alignment: .leading, spacing: 1.5) {
                Text(name.isEmpty ? "-" : name)
                    .font(.system(size: 14, weight: isCurrentPhase ? .heavy : .semibold))
                    .foregroundStyle(isCurrentPhase ? Color.white : Color.white.opacity(0.60))
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
                    .foregroundStyle(isCurrentPhase ? color : Color.white.opacity(0.35))
                Text("정거장")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(isCurrentPhase ? Color.white.opacity(0.85) : Color.white.opacity(0.30))
            }
        }
    }

    // MARK: - Lock Screen Card UI (High-Contrast Liquid Glass Aesthetic)
    @ViewBuilder
    private func lockScreenCard(state: BusRideActivityAttributes.ContentState) -> some View {
        VStack(spacing: 12) {
            // Header Row: Bus Badge + Active Tracking Phase & Scoreboard Countdown
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(RideTheme.primary, in: Circle())
                        .shadow(color: RideTheme.primary.opacity(0.6), radius: 4)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(state.routeNumber)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(state.isOnBoard ? RideTheme.liveGreen : RideTheme.boarding)
                                .frame(width: 6, height: 6)
                                .shadow(color: (state.isOnBoard ? RideTheme.liveGreen : RideTheme.boarding).opacity(0.8), radius: 3)
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
                            .foregroundStyle(.white.opacity(0.90))
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
                .overlay(Color.white.opacity(0.18))

            // Station rows: 승차 / 하차
            VStack(spacing: 7) {
                stopRow(
                    role: "승차",
                    name: state.boarding,
                    count: state.boardingRemainingStops,
                    currentLocation: !state.isOnBoard ? state.currentStation : nil,
                    color: RideTheme.boarding,
                    isCurrentPhase: !state.isOnBoard
                )

                stopRow(
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
        .background(
            ZStack {
                // Rich Translucent Slate Glass Canvas
                LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.16, blue: 0.22).opacity(0.94),
                        Color(red: 0.07, green: 0.09, blue: 0.14).opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle Radial Specular Glow
                RadialGradient(
                    colors: [
                        (state.isOnBoard ? RideTheme.accent : RideTheme.boarding).opacity(0.14),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 180
                )
            }
            .clipShape(ContainerRelativeShape())
        )
        .overlay(
            // Liquid Glass Specular Edge Highlight Border
            ContainerRelativeShape()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.40), Color.white.opacity(0.08), Color.white.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(ContainerRelativeShape())
        .activityBackgroundTint(Color.black.opacity(0.55))
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
