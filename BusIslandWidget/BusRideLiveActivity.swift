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
                    HStack(spacing: 6) {
                        Text("🚌")
                        Text(context.state.routeNumber)
                            .font(.title3.bold())
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.remainingStopsLabel)
                        .font(.title3.bold())
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.destination)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label("하차 알림", systemImage: "bell.fill")
                        Spacer()
                        Text("남은 \(context.state.remainingStops) 정거장")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Text("🚌 \(context.state.routeNumber)")
                    .font(.caption.bold())
                    .monospacedDigit()
            } compactTrailing: {
                Text(context.state.compactTrailingText)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } minimal: {
                Text(context.state.routeNumber)
                    .font(.caption2.bold())
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(state: BusRideActivityAttributes.ContentState) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("BusIsland", systemImage: "bus.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("🚌 \(state.routeNumber)")
                    .font(.title2.bold())
                    .monospacedDigit()

                Text(state.destination)
                    .font(.headline)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("남은 정거장")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(state.remainingStops)")
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.35))
        .activitySystemActionForegroundColor(.white)
    }
}
