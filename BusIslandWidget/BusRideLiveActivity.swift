import ActivityKit
import SwiftUI
import WidgetKit

private enum RideTheme {
    static let primary = Color(red: 0.18, green: 0.53, blue: 0.98) // Apple Blue
    static let accent = Color(red: 1.0, green: 0.58, blue: 0.0) // Warm Orange
    static let boarding = Color(red: 0.20, green: 0.78, blue: 0.65) // Mint Teal
    static let destination = Color(red: 1.0, green: 0.32, blue: 0.32) // Soft Coral
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
                            .background(context.state.isOnBoard ? RideTheme.primary : RideTheme.boarding, in: Circle())

                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.routeNumber)
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text(context.state.phaseTitle)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(context.state.isOnBoard ? Color.white.opacity(0.7) : RideTheme.boarding)
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(context.state.activeRemainingStops)")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(activeCountColor(for: context.state))
                            Text("정거장")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        Text(context.state.isOnBoard ? "하차까지" : "승차까지")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
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

                                    let progress: Double = {
                                        if !context.state.isOnBoard {
                                            // Waiting phase: 0.1 to 0.4
                                            return max(0.1, 0.4 - Double(context.state.boardingRemainingStops) * 0.08)
                                        } else {
                                            // Riding phase
                                            let total = max(1, context.state.remainingStops + 1)
                                            return min(1.0, max(0.4, 1.0 - (Double(context.state.remainingStops) / Double(total))))
                                        }
                                    }()

                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: context.state.isOnBoard
                                                    ? [RideTheme.boarding, RideTheme.accent]
                                                    : [RideTheme.boarding.opacity(0.6), RideTheme.boarding],
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
                                HStack(spacing: 4) {
                                    Text("승차")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(RideTheme.boarding)
                                    if !context.state.isOnBoard {
                                        Text("● 대기중")
                                            .font(.system(size: 8, weight: .heavy))
                                            .foregroundStyle(RideTheme.boarding)
                                    }
                                }
                                Text(context.state.boarding.isEmpty ? "출발지" : context.state.boarding)
                                    .font(.system(size: 12, weight: context.state.isOnBoard ? .regular : .bold))
                                    .foregroundStyle(context.state.isOnBoard ? .white.opacity(0.6) : .white)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(spacing: 4) {
                                    if context.state.isOnBoard {
                                        Text("● 이동중")
                                            .font(.system(size: 8, weight: .heavy))
                                            .foregroundStyle(RideTheme.accent)
                                    }
                                    Text("하차")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(RideTheme.destination)
                                }
                                Text(context.state.destination.isEmpty ? "도착지" : context.state.destination)
                                    .font(.system(size: 12, weight: context.state.isOnBoard ? .bold : .regular))
                                    .foregroundStyle(context.state.isOnBoard ? .white : .white.opacity(0.6))
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
                        .foregroundStyle(context.state.isOnBoard ? RideTheme.primary : RideTheme.boarding)
                    Text(context.state.routeNumber)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                }
                .padding(.leading, 4)
            } compactTrailing: {
                HStack(spacing: 3) {
                    Text(context.state.isOnBoard ? "하차" : "승차")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("\(context.state.activeRemainingStops)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(activeCountColor(for: context.state))
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
                        .background(state.isOnBoard ? RideTheme.primary : RideTheme.boarding, in: Circle())

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

            Divider()
                .overlay(Color.white.opacity(0.12))

            // Station timeline
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(RideTheme.boarding)
                        .frame(width: 8, height: 8)

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 5)

                        let progress: Double = {
                            if !state.isOnBoard {
                                return 0.2
                            } else {
                                let total = max(1, state.remainingStops + 1)
                                return min(1.0, max(0.3, 1.0 - (Double(state.remainingStops) / Double(total))))
                            }
                        }()

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [RideTheme.boarding, state.isOnBoard ? RideTheme.accent : RideTheme.boarding],
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
                        Text("승차 정류장")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RideTheme.boarding)
                        Text(state.boarding.isEmpty ? "출발 정류장" : state.boarding)
                            .font(.system(size: 13, weight: state.isOnBoard ? .regular : .bold))
                            .foregroundStyle(state.isOnBoard ? .white.opacity(0.7) : .white)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("하차 정류장")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RideTheme.destination)
                        Text(state.destination.isEmpty ? "도착 정류장" : state.destination)
                            .font(.system(size: 13, weight: state.isOnBoard ? .bold : .regular))
                            .foregroundStyle(state.isOnBoard ? .white : .white.opacity(0.7))
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

    private func activeCountColor(for state: BusRideActivityAttributes.ContentState) -> Color {
        if !state.isOnBoard {
            return state.boardingRemainingStops <= 1 ? RideTheme.destination : RideTheme.boarding
        } else {
            return state.remainingStops <= 1 ? RideTheme.destination : RideTheme.accent
        }
    }
}
