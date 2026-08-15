import SwiftUI
import UIKit

struct DebugConsoleView: View {
    @State private var store = DebugLogStore.shared
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            // Retro Terminal Banner
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.18, green: 0.84, blue: 0.38))
                        .frame(width: 8, height: 8)
                    Text("TERMINAL // BUSISLAND LOGS")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 0.18, green: 0.84, blue: 0.38))
                }
                Spacer()
                Text("[\(store.lines.count) EVENTS]")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(white: 0.12))
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )

            // Terminal Log Viewer
            ScrollView {
                Text(store.joinedText.isEmpty ? "› NO LOGS RECORDED" : store.joinedText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.18, green: 0.90, blue: 0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(14)
            }
            .background(Color.black)

            // Retro Control Panel
            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = store.joinedText
                    copied = true
                } label: {
                    HStack(spacing: 4) {
                        Text("📋")
                            .font(.system(size: 12))
                        Text("COPY ALL")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.25, green: 0.55, blue: 1.0))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                ShareLink(item: store.joinedText) {
                    HStack(spacing: 4) {
                        Text("📤")
                            .font(.system(size: 12))
                        Text("SHARE")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button(role: .destructive) {
                    store.clear()
                } label: {
                    HStack(spacing: 4) {
                        Text("🗑️")
                            .font(.system(size: 12))
                        Text("CLEAR")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(Color(red: 1.0, green: 0.22, blue: 0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay(
                Rectangle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .navigationTitle("LOG CONSOLE")
        .navigationBarTitleDisplayMode(.inline)
        .alert("복사됨", isPresented: $copied) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("로그가 클립보드에 복사되었습니다.")
        }
    }
}
