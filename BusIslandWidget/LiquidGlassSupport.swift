import SwiftUI

extension View {
    /// Official iOS 26 Liquid Glass. Falls back to ultraThinMaterial on earlier OS.
    @ViewBuilder
    func rideLiquidGlass<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
