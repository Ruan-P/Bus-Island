import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Apple Liquid Material Palette & System Tokens
private enum AppleGlassTheme {
    static let azure = Color(red: 0.0, green: 0.48, blue: 1.0)       // Apple System Blue
    static let teal = Color(red: 0.19, green: 0.69, blue: 0.78)      // Apple System Teal (승차)
    static let amber = Color(red: 1.0, green: 0.58, blue: 0.0)       // Apple System Orange (하차)
    static let coral = Color(red: 1.0, green: 0.23, blue: 0.19)      // Apple System Red (하차 임박)
    static let mint = Color(red: 0.20, green: 0.78, blue: 0.35)       // Apple System Green (Live Active)
}

struct BusRideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusRideActivityAttributes.self) { context in
            lockScreenCard(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        // Apple Glass Route Badge
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppleGlassTheme.azure.gradient)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.white.opacity(0.30), lineWidth: 0.75)
                                )

                            Image(systemName: "bus.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.routeNumber)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(context.state.phaseTitle)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(context.state.isOnBoard ? AppleGlassTheme.amber : AppleGlassTheme.teal)
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(context.state.activeRemainingStops)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(activeCountColor(for: context.state))
                            Text(context.state.isOnBoard ? "남음" : "전")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Text(context.state.isOnBoard ? "하차 정류소" : "승차 정류소")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // Location & Target Flow Pills
                        HStack(spacing: 6) {
                            // Current Location
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(AppleGlassTheme.teal)
                                Text(context.state.currentStation ?? context.state.boarding)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)

                            // Target Goal
                            HStack(spacing: 4) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(context.state.isOnBoard ? AppleGlassTheme.amber : AppleGlassTheme.teal)
                                Text(context.state.activeStationName)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background((context.state.isOnBoard ? AppleGlassTheme.amber : AppleGlassTheme.teal).opacity(0.18), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                            Spacer(minLength: 0)

                            Text(context.state.isOnBoard ? "\(context.state.remainingStops)정거장" : "\(context.state.boardingRemainingStops)전")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(activeCountColor(for: context.state))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        // Apple Glass Progress Bar
                        appleProgressBar(state: context.state)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .clipShape(ContainerRelativeShape())
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppleGlassTheme.azure)
                    Text(context.state.routeNumber)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .padding(.leading, 4)
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text(context.state.isOnBoard ? "하차" : "승차")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(context.state.activeRemainingStops)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(activeCountColor(for: context.state))
                        .lineLimit(1)
                }
                .padding(.trailing, 4)
            } minimal: {
                Text("\(context.state.activeRemainingStops)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(activeCountColor(for: context.state))
            }
            .keylineTint(context.state.isOnBoard ? AppleGlassTheme.amber : AppleGlassTheme.teal)
        }
    }

    // MARK: - Apple Liquid Progress Tube
    @ViewBuilder
    private func appleProgressBar(state: BusRideActivityAttributes.ContentState) -> some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let currentProgress = CGFloat(state.progress)
            let activeWidth = max(12, min(totalWidth, totalWidth * currentProgress))

            ZStack(alignment: .leading) {
                // Glass track
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 6)

                // Active Liquid Bar
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: state.isOnBoard
                                ? [AppleGlassTheme.teal, AppleGlassTheme.amber]
                                : [AppleGlassTheme.azure, AppleGlassTheme.teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: activeWidth, height: 6)

                // Transit bead
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .offset(x: max(0, activeWidth - 5))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 10)
    }

    // MARK: - Authentic Apple Material & Liquid Glass Lock Screen Card (Spacious & Breathable)
    @ViewBuilder
    private func lockScreenCard(state: BusRideActivityAttributes.ContentState) -> some View {
        VStack(spacing: 14) {
            // MARK: - 1. Header: Bus Route Badge + Live Status + Large Countdown
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    // Refined Glass Route Emblem
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(AppleGlassTheme.azure.gradient)
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.10)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.75
                                    )
                            )
                            .shadow(color: AppleGlassTheme.azure.opacity(0.35), radius: 5, x: 0, y: 2)

                        Image(systemName: "bus.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.routeNumber)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        HStack(spacing: 5) {
                            Circle()
                                .fill(state.isOnBoard ? AppleGlassTheme.mint : AppleGlassTheme.teal)
                                .frame(width: 6, height: 6)
                            Text(state.isOnBoard ? "하차지 이동 중 · LIVE" : "승차 대기 중 · LIVE")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(state.isOnBoard ? AppleGlassTheme.mint : AppleGlassTheme.teal)
                        }
                    }
                }

                Spacer()

                // Large Glass Scoreboard Countdown
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(String(format: "%02d", state.activeRemainingStops))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(activeCountColor(for: state))
                        Text(state.isOnBoard ? "정거장 남음" : "정거장 전")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    Text(state.isOnBoard ? "목표 하차지까지" : "승차 정류소까지")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
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
                                colors: [activeCountColor(for: state).opacity(0.50), activeCountColor(for: state).opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                )
            }

            // MARK: - 2. Spacious Transit Flow (Clean & Unboxed)
            VStack(spacing: 9) {
                // Real-time Current Location Line
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppleGlassTheme.teal)

                    Text("현재 위치")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(state.currentStation ?? (state.isOnBoard ? state.destination : state.boarding))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(state.isOnBoard ? "운행 중" : "접근 중")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }

                // Target Destination Goal Line
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(state.isOnBoard ? AppleGlassTheme.amber : AppleGlassTheme.teal)

                    Text(state.activeStationRole)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(state.isOnBoard ? AppleGlassTheme.amber : AppleGlassTheme.teal)

                    Text(state.activeStationName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()
                }
            }
            .padding(.horizontal, 4)

            // MARK: - 3. Apple Glass Journey Progress Tube
            appleProgressBar(state: state)
                .padding(.horizontal, 2)
                .padding(.top, 2)
        }
        .padding(18)
        .background(
            ZStack {
                // Deep Obsidian Glass Material Base
                Color(white: 0.11).opacity(0.90)

                // Ambient Radial Light Tint
                RadialGradient(
                    colors: [
                        (state.isOnBoard ? AppleGlassTheme.amber : AppleGlassTheme.azure).opacity(0.14),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 190
                )
            }
            .clipShape(ContainerRelativeShape())
        )
        .overlay(
            // Delicate Specular Glass Rim Reflection
            ContainerRelativeShape()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.26), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
        )
        .clipShape(ContainerRelativeShape())
        .activityBackgroundTint(Color.black.opacity(0.60))
        .activitySystemActionForegroundColor(.white)
    }

    private func activeCountColor(for state: BusRideActivityAttributes.ContentState) -> Color {
        if !state.isOnBoard {
            return state.boardingRemainingStops <= 1 ? AppleGlassTheme.coral : AppleGlassTheme.teal
        } else {
            return state.remainingStops <= 1 ? AppleGlassTheme.coral : AppleGlassTheme.amber
        }
    }
}
