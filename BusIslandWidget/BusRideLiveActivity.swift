import ActivityKit
import SwiftUI
import WidgetKit

private enum RideAccent {
    static let boarding = Color.cyan
    static let alighting = Color.orange
}

struct BusRideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusRideActivityAttributes.self) { context in
            lockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "bus.fill")
                            .font(.title3)
                            .foregroundStyle(RideAccent.alighting)
                        Text(context.state.routeNumber)
                            .font(.title2.bold())
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.leading, 14)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.remainingStops)")
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(RideAccent.alighting)
                        .lineLimit(1)
                        .padding(.trailing, 14)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        stopRow(
                            role: "승차",
                            name: context.state.boarding,
                            count: context.state.boardingRemainingStops,
                            color: RideAccent.boarding
                        )
                        stopRow(
                            role: "하차",
                            name: context.state.destination,
                            count: context.state.remainingStops,
                            color: RideAccent.alighting
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipShape(ContainerRelativeShape())
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "bus.fill")
                        .font(.caption2)
                        .foregroundStyle(RideAccent.alighting)
                    Text(context.state.routeNumber)
                        .font(.caption.bold())
                        .monospacedDigit()
                        .lineLimit(1)
                }
            } compactTrailing: {
                Text(context.state.compactTrailingText)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(RideAccent.alighting)
                    .lineLimit(1)
            } minimal: {
                Text(context.state.minimalDisplayText)
                    .font(.caption2.bold())
                    .monospacedDigit()
                    .foregroundStyle(RideAccent.alighting)
            }
            .keylineTint(RideAccent.alighting)
        }
    }

    @ViewBuilder
    private func stopRow(role: String, name: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(role)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 28, alignment: .leading)
            Text(name.isEmpty ? "-" : name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(count)")
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func lockScreenView(state: BusRideActivityAttributes.ContentState) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "bus.fill")
                        .font(.title3)
                        .foregroundStyle(RideAccent.alighting)
                    Text(state.routeNumber)
                        .font(.title2.bold())
                        .monospacedDigit()
                        .lineLimit(1)
                }

                stopRow(
                    role: "승차",
                    name: state.boarding,
                    count: state.boardingRemainingStops,
                    color: RideAccent.boarding
                )
                stopRow(
                    role: "하차",
                    name: state.destination,
                    count: state.remainingStops,
                    color: RideAccent.alighting
                )
            }

            Spacer(minLength: 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.28), in: ContainerRelativeShape())
        .clipShape(ContainerRelativeShape())
        .activityBackgroundTint(Color.black.opacity(0.35))
        .activitySystemActionForegroundColor(.white)
    }
}
