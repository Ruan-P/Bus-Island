import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Liquid Glass Theme & Visual Tokens
private enum LiquidGlassTheme {
    static let royalAzure = Color(red: 0.15, green: 0.45, blue: 0.98)
    static let electricCyan = Color(red: 0.0, green: 0.95, blue: 1.0)
    static let neonMint = Color(red: 0.05, green: 0.88, blue: 0.72)
    static let amberOrange = Color(red: 1.0, green: 0.55, blue: 0.0)
    static let alertCoral = Color(red: 1.0, green: 0.20, blue: 0.38)
    static let livePulse = Color(red: 0.08, green: 0.90, blue: 0.45)
    
    // Prismatic Refractive Border Gradient for Liquid Glass
    static var liquidRefractiveBorder: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.65), location: 0.0),
                .init(color: electricCyan.opacity(0.35), location: 0.25),
                .init(color: Color.white.opacity(0.12), location: 0.65),
                .init(color: amberOrange.opacity(0.30), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
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
                        // Glossy Liquid Glass Bus Capsule
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            LiquidGlassTheme.royalAzure.opacity(0.95),
                                            LiquidGlassTheme.royalAzure.opacity(0.60)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    // Specular light reflection on top half
                                    VStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.45), Color.clear],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(height: 14)
                                        Spacer()
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.white.opacity(0.40), lineWidth: 1)
                                )
                                .shadow(color: LiquidGlassTheme.electricCyan.opacity(0.30), radius: 4, x: 0, y: 2)

                            Image(systemName: "bus.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.routeNumber)
                                .font(.system(size: 17, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(context.state.phaseTitle)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(context.state.isOnBoard ? LiquidGlassTheme.amberOrange : LiquidGlassTheme.neonMint)
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text("\(context.state.activeRemainingStops)")
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundStyle(activeCountColor(for: context.state))
                            Text(context.state.isOnBoard ? "남음" : "전")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.88))
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
                        // Liquid Glass Location Flow Pills
                        HStack(spacing: 6) {
                            // Current Location Liquid Pill
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(LiquidGlassTheme.electricCyan)
                                Text(context.state.currentStation ?? context.state.boarding)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(LiquidGlassTheme.electricCyan.opacity(0.35), lineWidth: 0.75)
                            )

                            Text("▶")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(Color.white.opacity(0.35))

                            // Target Goal Liquid Pill
                            HStack(spacing: 4) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(context.state.isOnBoard ? LiquidGlassTheme.amberOrange : LiquidGlassTheme.neonMint)
                                Text(context.state.activeStationName)
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill((context.state.isOnBoard ? LiquidGlassTheme.amberOrange : LiquidGlassTheme.neonMint).opacity(0.16))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke((context.state.isOnBoard ? LiquidGlassTheme.amberOrange : LiquidGlassTheme.neonMint).opacity(0.40), lineWidth: 0.75)
                            )

                            Spacer(minLength: 0)

                            Text(context.state.isOnBoard ? "\(context.state.remainingStops)정거장" : "\(context.state.boardingRemainingStops)전")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(activeCountColor(for: context.state))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )

                        // Liquid Glass Journey Tube
                        liquidProgressBar(state: context.state)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .clipShape(ContainerRelativeShape())
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.electricCyan)
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
            .keylineTint(context.state.isOnBoard ? LiquidGlassTheme.amberOrange : LiquidGlassTheme.neonMint)
        }
    }

    // MARK: - Fluid Liquid Glass Journey Progress Tube
    @ViewBuilder
    private func liquidProgressBar(state: BusRideActivityAttributes.ContentState) -> some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let currentProgress = CGFloat(state.progress)
            let activeWidth = max(12, min(totalWidth, totalWidth * currentProgress))

            ZStack(alignment: .leading) {
                // Glass Outer Chamber Tube
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 7)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    )

                // Fluid Neon Liquid Column
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: state.isOnBoard
                                ? [LiquidGlassTheme.neonMint, LiquidGlassTheme.amberOrange]
                                : [LiquidGlassTheme.electricCyan.opacity(0.75), LiquidGlassTheme.electricCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: activeWidth, height: 7)
                    .overlay(
                        // Top liquid gloss shine
                        VStack {
                            Capsule()
                                .fill(Color.white.opacity(0.50))
                                .frame(height: 2)
                            Spacer()
                        }
                    )
                    .shadow(
                        color: (state.isOnBoard ? LiquidGlassTheme.amberOrange : LiquidGlassTheme.electricCyan).opacity(0.50),
                        radius: 4,
                        x: 0,
                        y: 0
                    )

                // Glowing Refractive Glass Droplet / Bus Bead
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white, Color.white.opacity(0.85)],
                                center: .topLeading,
                                startRadius: 1,
                                endRadius: 8
                            )
                        )
                        .frame(width: 11, height: 11)
                        .shadow(color: Color.black.opacity(0.60), radius: 3, x: 0, y: 1)
                        .shadow(
                            color: (state.isOnBoard ? LiquidGlassTheme.amberOrange : LiquidGlassTheme.electricCyan).opacity(0.80),
                            radius: 5,
                            x: 0,
                            y: 0
                        )

                    Circle()
                        .stroke(Color.white.opacity(0.90), lineWidth: 0.75)
                        .frame(width: 11, height: 11)
                }
                .offset(x: max(0, activeWidth - 5.5))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 12)
    }

    // MARK: - Ultra-Premium Liquid Glass Lock Screen Card
    @ViewBuilder
    private func lockScreenCard(state: BusRideActivityAttributes.ContentState) -> some View {
        VStack(spacing: 12) {
            // MARK: - 1. Liquid Glass Header: 3D Glossy Emblem + Beacon + Refractive Scoreboard
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    // 3D Liquid Glass Route Emblem
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        LiquidGlassTheme.royalAzure.opacity(0.95),
                                        LiquidGlassTheme.royalAzure.opacity(0.65)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                // Top specular light reflection sheen
                                VStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.55), Color.clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(height: 16)
                                    Spacer()
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.65), Color.white.opacity(0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: LiquidGlassTheme.electricCyan.opacity(0.40), radius: 6, x: 0, y: 3)

                        Image(systemName: "bus.fill")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.routeNumber)
                            .font(.system(size: 21, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)

                        // Liquid Pulse Beacon
                        HStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill((state.isOnBoard ? LiquidGlassTheme.livePulse : LiquidGlassTheme.electricCyan).opacity(0.35))
                                    .frame(width: 10, height: 10)
                                Circle()
                                    .fill(state.isOnBoard ? LiquidGlassTheme.livePulse : LiquidGlassTheme.electricCyan)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: (state.isOnBoard ? LiquidGlassTheme.livePulse : LiquidGlassTheme.electricCyan).opacity(0.90), radius: 4)
                            }

                            Text(state.isOnBoard ? "하차지 이동 중 · LIVE" : "승차 대기 중 · LIVE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(state.isOnBoard ? LiquidGlassTheme.livePulse : LiquidGlassTheme.electricCyan)
                        }
                    }
                }

                Spacer()

                // Refractive Liquid Scoreboard Capsule
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(String(format: "%02d", state.activeRemainingStops))
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(activeCountColor(for: state))
                        Text(state.isOnBoard ? "정거장 남음" : "정거장 전")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    Text(state.isOnBoard ? "목표 하차지까지" : "승차 정류소까지")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    activeCountColor(for: state).opacity(0.70),
                                    Color.white.opacity(0.35),
                                    activeCountColor(for: state).opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: activeCountColor(for: state).opacity(0.25), radius: 6, x: 0, y: 2)
            }

            // MARK: - 2. Dual Liquid Glass Panels (Location & Target)
            VStack(spacing: 6) {
                // Real-time Current Location Liquid Capsule
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LiquidGlassTheme.electricCyan)
                        Text("현재 위치")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(LiquidGlassTheme.electricCyan)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LiquidGlassTheme.electricCyan.opacity(0.16))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(LiquidGlassTheme.electricCyan.opacity(0.40), lineWidth: 0.75)
                    )

                    Text(state.currentStation ?? (state.isOnBoard ? state.destination : state.boarding))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(state.isOnBoard ? "운행 중" : "접근 중")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                }

                // Target Destination Goal Liquid Capsule
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(state.isOnBoard ? LiquidGlassTheme.amberOrange : LiquidGlassTheme.neonMint)
                        Text(state.activeStationRole)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(state.isOnBoard ? LiquidGlassTheme.amberOrange : LiquidGlassTheme.neonMint)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill((state.isOnBoard ? LiquidGlassTheme.amberOrange : LiquidGlassTheme.neonMint).opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke((state.isOnBoard ? LiquidGlassTheme.amberOrange : LiquidGlassTheme.neonMint).opacity(0.45), lineWidth: 0.75)
                    )

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
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )

            // MARK: - 3. Liquid Glass Journey Progress Tube
            liquidProgressBar(state: state)
                .padding(.horizontal, 2)
        }
        .padding(16)
        .background(
            ZStack {
                // Base Fluid Translucent Liquid Body
                LinearGradient(
                    colors: [
                        Color(white: 0.15).opacity(0.96),
                        Color(white: 0.07).opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Iridescent Radial Ambient Glow
                RadialGradient(
                    colors: [
                        (state.isOnBoard ? LiquidGlassTheme.amberOrange : LiquidGlassTheme.electricCyan).opacity(0.14),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 200
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(
            // Prismatic Refractive Outer Liquid Rim
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(LiquidGlassTheme.liquidRefractiveBorder, lineWidth: 1)
        )
        .clipShape(ContainerRelativeShape())
        .activityBackgroundTint(Color.black.opacity(0.65))
        .activitySystemActionForegroundColor(.white)
    }

    private func activeCountColor(for state: BusRideActivityAttributes.ContentState) -> Color {
        if !state.isOnBoard {
            return state.boardingRemainingStops <= 1 ? LiquidGlassTheme.alertCoral : LiquidGlassTheme.electricCyan
        } else {
            return state.remainingStops <= 1 ? LiquidGlassTheme.alertCoral : LiquidGlassTheme.amberOrange
        }
    }
}
