import ActivityKit
import SwiftUI
import WidgetKit

private enum RideTheme {
    static let primary = Color(red: 0.20, green: 0.48, blue: 0.98) // Electric Blue (노선)
    static let accent = Color(red: 1.0, green: 0.55, blue: 0.05)   // Warm Amber (하차)
    static let boarding = Color(red: 0.0, green: 0.78, blue: 0.78)  // Cyan-Teal (승차)
    static let alertRed = Color(red: 1.0, green: 0.22, blue: 0.35) // Alert Coral/Red (하차 1정거장 이하)
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
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(RideTheme.primary, in: RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.routeNumber)
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(context.state.phaseTitle)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(context.state.isOnBoard ? RideTheme.accent : RideTheme.boarding)
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(context.state.activeRemainingStops)")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundStyle(activeCountColor(for: context.state))
                            Text(context.state.isOnBoard ? "남음" : "전")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Text(context.state.isOnBoard ? "하차 정류장" : "승차 정류장")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Current Target Station Focus Pill
                        HStack(spacing: 6) {
                            Text(context.state.activeStationRole)
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(context.state.isOnBoard ? RideTheme.accent : RideTheme.boarding)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background((context.state.isOnBoard ? RideTheme.accent : RideTheme.boarding).opacity(0.18), in: RoundedRectangle(cornerRadius: 4))

                            Text(context.state.activeStationName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Spacer()

                            Text(context.state.isOnBoard ? "\(context.state.remainingStops)정거장 남음" : "\(context.state.boardingRemainingStops)정거장 전")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(activeCountColor(for: context.state))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

                        // Streamlined Journey Progress Bar
                        journeyProgressBar(state: context.state)
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
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .lineLimit(1)
                }
                .padding(.leading, 4)
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text(context.state.isOnBoard ? "하차" : "승차")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("\(context.state.activeRemainingStops)")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(activeCountColor(for: context.state))
                        .lineLimit(1)
                }
                .padding(.trailing, 4)
            } minimal: {
                Text("\(context.state.activeRemainingStops)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(activeCountColor(for: context.state))
            }
            .keylineTint(context.state.isOnBoard ? RideTheme.accent : RideTheme.boarding)
        }
    }

    // MARK: - Streamlined Journey Progress Bar
    @ViewBuilder
    private func journeyProgressBar(state: BusRideActivityAttributes.ContentState) -> some View {
        VStack(spacing: 4) {
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

                    // Moving Bus Indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, activeWidth - 4))
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 8)

            // Origin & Destination Milestones
            HStack {
                Text("승차: \(state.boarding.isEmpty ? "-" : state.boarding)")
                    .font(.system(size: 10, weight: state.isOnBoard ? .regular : .bold))
                    .foregroundStyle(state.isOnBoard ? Color.white.opacity(0.5) : RideTheme.boarding)
                    .lineLimit(1)

                Spacer()

                Text("하차: \(state.destination.isEmpty ? "-" : state.destination)")
                    .font(.system(size: 10, weight: state.isOnBoard ? .bold : .regular))
                    .foregroundStyle(state.isOnBoard ? RideTheme.accent : Color.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Lock Screen Card UI (Clean, Spacious & High-Impact)
    @ViewBuilder
    private func lockScreenCard(state: BusRideActivityAttributes.ContentState) -> some View {
        VStack(spacing: 12) {
            // Header Row: Bus Badge + Active Tracking Phase & Scoreboard
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(RideTheme.primary, in: RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.routeNumber)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(state.isOnBoard ? Color.green : RideTheme.boarding)
                                .frame(width: 6, height: 6)
                            Text(state.isOnBoard ? "하차지 이동 중" : "승차 대기 중")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(state.isOnBoard ? Color.green : RideTheme.boarding)
                        }
                    }
                }

                Spacer()

                // Big Scoreboard Countdown
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(String(format: "%02d", state.activeRemainingStops))
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundStyle(activeCountColor(for: state))
                        Text(state.isOnBoard ? "정거장 남음" : "정거장 전")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text(state.isOnBoard ? "목표 하차지까지" : "승차 정류소까지")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(activeCountColor(for: state).opacity(0.35), lineWidth: 1)
                )
            }

            // Target Station Hero Banner
            HStack(spacing: 8) {
                Text(state.activeStationRole)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(state.isOnBoard ? RideTheme.accent : RideTheme.boarding)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background((state.isOnBoard ? RideTheme.accent : RideTheme.boarding).opacity(0.2), in: RoundedRectangle(cornerRadius: 4))

                Text(state.activeStationName)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text(state.isOnBoard ? "\(state.remainingStops)정거장 남음" : "\(state.boardingRemainingStops)정거장 전")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(activeCountColor(for: state))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            // Realtime Progress Bar & Route Endpoints
            journeyProgressBar(state: state)
                .padding(.horizontal, 2)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(white: 0.14), Color(white: 0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .clipShape(ContainerRelativeShape())
        .activityBackgroundTint(Color.black.opacity(0.6))
        .activitySystemActionForegroundColor(.white)
    }

    private func activeCountColor(for state: BusRideActivityAttributes.ContentState) -> Color {
        if !state.isOnBoard {
            return state.boardingRemainingStops <= 1 ? RideTheme.alertRed : RideTheme.boarding
        } else {
            return state.remainingStops <= 1 ? RideTheme.alertRed : RideTheme.accent
        }
    }
}
