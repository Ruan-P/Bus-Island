import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var serviceKey: String = ""
    @State private var savedBanner = false
    @State private var usingBaked = true
    @State private var debugLog = DebugLogStore.shared

    var body: some View {
        Form {
            // MARK: - API Key Section
            Section {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.blue)
                    Text("API 키 상태")
                    Spacer()
                    Text(usingBaked ? "빌드 기본 키" : "사용자 지정 키")
                        .font(.subheadline)
                        .foregroundStyle(usingBaked ? Color.secondary : Color.blue)
                }

                SecureField("serviceKey 입력 (공공데이터포털)", text: $serviceKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())

                Button {
                    let trimmed = serviceKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    APIKeyStore.shared.serviceKey = trimmed.isEmpty ? nil : trimmed
                    refreshState()
                    savedBanner = true
                } label: {
                    Text("새 키 저장하기")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(serviceKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !usingBaked {
                    Button("기본 빌드 키로 재설정", role: .destructive) {
                        APIKeyStore.shared.serviceKey = nil
                        serviceKey = ""
                        refreshState()
                    }
                }
            } header: {
                Text("GBIS / TAGO API 설정")
            } footer: {
                Text("공공데이터포털 인증키(Decoding / Encoding) 모두 지원합니다. 키가 없더라도 빌드 기본 키로 동작합니다.")
                    .font(.caption2)
            }

            // MARK: - Developer / Debug Tools
            Section("개발 및 진단 도구") {
                NavigationLink {
                    DebugConsoleView()
                } label: {
                    HStack {
                        Label("디버그 로그 콘솔", systemImage: "terminal.fill")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(debugLog.lines.count)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                    }
                }
            }

            // MARK: - App Information
            Section("앱 정보") {
                LabeledContent("앱 이름", value: "BusIsland")
                LabeledContent("버전", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("빌드", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                LabeledContent("디스플레이", value: "Dynamic Island + Live Activity")
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshState() }
        .alert("저장 완료", isPresented: $savedBanner) {
            Button("확인") { dismiss() }
        } message: {
            Text("API 인증키가 안전하게 저장되었습니다.")
        }
    }

    private func refreshState() {
        usingBaked = APIKeyStore.shared.isUsingBakedDefault
        if !usingBaked {
            serviceKey = APIKeyStore.shared.serviceKey ?? ""
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
