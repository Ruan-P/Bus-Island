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
                            .font(.title3)
                            .foregroundStyle(.orange)
                        Text(context.state.routeNumber)
                            .font(.title3.bold())
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(context.state.remainingStops)")
                            .font(.title2.bold())
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                        Text(context.state.remainingStopsUnit)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.destination)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "bus.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(context.state.routeNumber)
                        .font(.caption.bold())
                        .monospacedDigit()
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
    private func lockScreenView(state: BusRideActivityAttributes.ContentState) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "bus.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(state.routeNumber)
                        .font(.title2.bold())
                        .monospacedDigit()
                }

                Text(state.destination)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(state.remainingStops)")
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                Text(state.remainingStopsUnit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.35))
        .activitySystemActionForegroundColor(.white)
    }
}
