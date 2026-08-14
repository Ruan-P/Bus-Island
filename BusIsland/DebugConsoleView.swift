import SwiftUI
import UIKit

struct DebugConsoleView: View {
    @State private var store = DebugLogStore.shared
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(store.joinedText.isEmpty ? "(로그 없음)" : store.joinedText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }

            HStack(spacing: 12) {
                Button("전체 복사") {
                    UIPasteboard.general.string = store.joinedText
                    copied = true
                }
                .buttonStyle(.borderedProminent)

                ShareLink(item: store.joinedText) {
                    Label("공유", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)

                Button("지우기", role: .destructive) {
                    store.clear()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("디버그 콘솔")
        .navigationBarTitleDisplayMode(.inline)
        .alert("복사됨", isPresented: $copied) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("로그를 채팅에 붙여넣으면 됩니다.")
        }
    }
}
