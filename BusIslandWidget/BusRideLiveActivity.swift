import ActivityKit
import SwiftUI
import WidgetKit

private enum GlassTheme {
    static let primary = Color(red: 0.23, green: 0.51, blue: 0.96)     // Royal Azure
    static let cyan = Color(red: 0.0, green: 0.95, blue: 1.0)          // Electric Neon Cyan
    static let boarding = Color(red: 0.05, green: 0.85, blue: 0.80)    // Mint-Teal (승차)
    static let accent = Color(red: 1.0, green: 0.55, blue: 0.0)        // Vibrant Amber (하차)
    static let alertRed = Color(red: 1.0, green: 0.20, blue: 0.40)     // Alert Coral (하차 임박)
    static let liveGreen = Color(red: 0.06, green: 0.85, blue: 0.45)    // Live Pulse Green
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
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [GlassTheme.primary.opacity(0.9), GlassTheme.primary.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                )
                            Image(systemName: "bus.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.routeNumber)
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(context.state.phaseTitle)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(context.state.isOnBoard ? GlassTheme.accent : GlassTheme.boarding)
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text("\(context.state.activeRemainingStops)")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundStyle(activeCountColor(for: context.state))
                            Text(context.state.isOnBoard ? "남음" : "전")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Text(context.state.isOnBoard ? "하차 정류소" : "승차 정류소")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Live Tracked Bus Location & Target Banner
                        HStack(spacing: 6) {
                            // Current Location Pill
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(GlassTheme.cyan)
                                Text(context.state.currentStation ?? context.state.boarding)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

                            Text("▶")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(Color.white.opacity(0.35))

                            // Target Goal Pill
                            HStack(spacing: 4) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(context.state.isOnBoard ? GlassTheme.accent : GlassTheme.boarding)
                                Text(context.state.activeStationName)
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background((context.state.isOnBoard ? GlassTheme.accent : GlassTheme.boarding).opacity(0.18), in: RoundedRectangle(cornerRadius: 6))

                            Spacer(minLength: 0)

                            Text(context.state.isOnBoard ? "\(context.state.remainingStops)정거장" : "\(context.state.boardingRemainingStops)전")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(activeCountColor(for: context.state))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

                        // Frosted Glass Journey Progress Bar
                        frostedProgressBar(state: context.state)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .clipShape(ContainerRelativeShape())
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(GlassTheme.cyan)
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
            .keylineTint(context.state.isOnBoard ? GlassTheme.accent : GlassTheme.boarding)
        }
    }

    // MARK: - Frosted Glass Journey Progress Bar
    @ViewBuilder
    private func frostedProgressBar(state: BusRideActivityAttributes.ContentState) -> some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let currentProgress = CGFloat(state.progress)
            let activeWidth = max(10, min(totalWidth, totalWidth * currentProgress))

            ZStack(alignment: .leading) {
                // Frosted translucent track
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 6)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )

                // Neon active fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: state.isOnBoard
                                ? [GlassTheme.boarding, GlassTheme.accent]
                                : [GlassTheme.cyan.opacity(0.8), GlassTheme.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: activeWidth, height: 6)
                    .shadow(color: (state.isOnBoard ? GlassTheme.accent : GlassTheme.cyan).opacity(0.4), radius: 3, x: 0, y: 0)

                // Glowing Glass Bus Head
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.black.opacity(0.6), radius: 2, x: 0, y: 1)
                    .offset(x: max(0, activeWidth - 5))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 10)
    }

    // MARK: - Ultra-Modern Glassmorphism Lock Screen Card
    @ViewBuilder
    private func lockScreenCard(state: BusRideActivityAttributes.ContentState) -> some View {
        VStack(spacing: 12) {
            // MARK: - 1. Glass Header: Route Emblem + Live Pulse + Digital Scoreboard
            HStack(alignment: .center) {
                HStack(spacing: 9) {
                    // Frosted Glass Route Emblem
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [GlassTheme.primary.opacity(0.95), GlassTheme.primary.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: GlassTheme.primary.opacity(0.4), radius: 4, x: 0, y: 2)

                        Image(systemName: "bus.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.routeNumber)
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)

                        HStack(spacing: 5) {
                            Circle()
                                .fill(state.isOnBoard ? GlassTheme.liveGreen : GlassTheme.cyan)
                                .frame(width: 6, height: 6)
                                .shadow(color: (state.isOnBoard ? GlassTheme.liveGreen : GlassTheme.cyan).opacity(0.8), radius: 3)
                            Text(state.isOnBoard ? "하차지 이동 중 · LIVE" : "승차 대기 중 · LIVE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(state.isOnBoard ? GlassTheme.liveGreen : GlassTheme.cyan)
                        }
                    }
                }

                Spacer()

                // Glass Scoreboard Countdown Pill
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(String(format: "%02d", state.activeRemainingStops))
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(activeCountColor(for: state))
                        Text(state.isOnBoard ? "정거장 남음" : "정거장 전")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Text(state.isOnBoard ? "목표 하차지까지" : "승차 정류소까지")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [activeCountColor(for: state).opacity(0.6), activeCountColor(for: state).opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }

            // MARK: - 2. Live Bus Location & Target Glass Panel
            VStack(spacing: 6) {
                // Current Location Row
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(GlassTheme.cyan)
                        Text("현재 위치")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(GlassTheme.cyan)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(GlassTheme.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))

                    Text(state.currentStation ?? (state.isOnBoard ? state.destination : state.boarding))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(state.isOnBoard ? "운행 중" : "접근 중")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }

                // Target Goal Row
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(state.isOnBoard ? GlassTheme.accent : GlassTheme.boarding)
                        Text(state.activeStationRole)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(state.isOnBoard ? GlassTheme.accent : GlassTheme.boarding)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background((state.isOnBoard ? GlassTheme.accent : GlassTheme.boarding).opacity(0.18), in: RoundedRectangle(cornerRadius: 5))

                    Text(state.activeStationName)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(state.isOnBoard ? "\(state.remainingStops)정거장 남음" : "\(state.boardingRemainingStops)정거장 전")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(activeCountColor(for: state))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            // MARK: - 3. Frosted Glass Journey Progress Capsule
            frostedProgressBar(state: state)
                .padding(.horizontal, 2)
        }
        .padding(16)
        .background(
            ZStack {
                // Base Frosted Glass Gradient
                LinearGradient(
                    colors: [Color(white: 0.16).opacity(0.96), Color(white: 0.08).opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle Radial Specular Glow
                RadialGradient(
                    colors: [(state.isOnBoard ? GlassTheme.accent : GlassTheme.cyan).opacity(0.12), Color.clear],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 180
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(ContainerRelativeShape())
        .activityBackgroundTint(Color.black.opacity(0.6))
        .activitySystemActionForegroundColor(.white)
    }

    private func activeCountColor(for state: BusRideActivityAttributes.ContentState) -> Color {
        if !state.isOnBoard {
            return state.boardingRemainingStops <= 1 ? GlassTheme.alertRed : GlassTheme.cyan
        } else {
            return state.remainingStops <= 1 ? GlassTheme.alertRed : GlassTheme.accent
        }
    }
}
