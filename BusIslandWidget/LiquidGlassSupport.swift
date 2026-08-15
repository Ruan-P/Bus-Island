import SwiftUI

extension View {
    /// Convenience wrapper for iOS 26 Liquid Glass effect with optional tint.
    @ViewBuilder
    func rideLiquidGlass<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        if let tint {
            self.glassEffect(.regular.tint(tint), in: shape)
        } else {
            self.glassEffect(.regular, in: shape)
        }
    }
}
