import ActivityKit
import SwiftUI
import WidgetKit

struct BusRideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusRideActivityAttributes.self) { context in
            lockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "bus.fill")
                            .font(.body)
                            .foregroundStyle(.orange)
                        Text(context.state.routeNumber)
                            .font(.headline.bold())
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.remainingStops)")
                        .font(.headline.bold())
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        labeledStop(role: "승차", name: context.state.boarding)
                        labeledStop(role: "하차", name: context.state.destination)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "bus.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(context.state.routeNumber)
                        .font(.caption.bold())
                        .monospacedDigit()
                        .lineLimit(1)
                }
            } compactTrailing: {
                Text(context.state.compactTrailingText)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            } minimal: {
                Text(context.state.minimalDisplayText)
                    .font(.caption2.bold())
                    .monospacedDigit()
                    .foregroundStyle(.orange)
            }
            .keylineTint(.orange)
        }
    }

    @ViewBuilder
    private func labeledStop(role: String, name: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(role)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            Text(name.isEmpty ? "-" : name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private func lockScreenView(state: BusRideActivityAttributes.ContentState) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "bus.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(state.routeNumber)
                        .font(.headline.bold())
                        .monospacedDigit()
                }

                labeledStop(role: "승차", name: state.boarding)
                labeledStop(role: "하차", name: state.destination)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(state.remainingStops)")
                    .font(.title.bold())
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                Text(state.remainingStopsUnit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .activityBackgroundTint(Color.black.opacity(0.35))
        .activitySystemActionForegroundColor(.white)
    }
}
