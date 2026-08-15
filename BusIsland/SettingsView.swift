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
                    Text("API 인증키 상태")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(usingBaked ? "빌드 기본 키" : "사용자 등록 키")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(usingBaked ? Color.secondary : Color(red: 0.20, green: 0.48, blue: 0.98))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((usingBaked ? Color.secondary : Color(red: 0.20, green: 0.48, blue: 0.98)).opacity(0.12), in: Capsule())
                }

                SecureField("serviceKey 입력 (공공데이터포털)", text: $serviceKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 13, design: .monospaced))

                Button {
                    let trimmed = serviceKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    APIKeyStore.shared.serviceKey = trimmed.isEmpty ? nil : trimmed
                    refreshState()
                    savedBanner = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 12))
                        Text("새 인증키 저장")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.20, green: 0.48, blue: 0.98))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(serviceKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !usingBaked {
                    Button(role: .destructive) {
                        APIKeyStore.shared.serviceKey = nil
                        serviceKey = ""
                        refreshState()
                    } label: {
                        Text("기본 인증키로 되돌리기")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                }
            } header: {
                Text("GBIS / TAGO API 인증키")
                    .font(.system(size: 12, weight: .bold))
            } footer: {
                Text("공공데이터포털 인증키(Decoding / Encoding)를 모두 지원합니다. 키가 없더라도 앱에 내장된 기본 키로 즉시 동작합니다.")
                    .font(.system(size: 11))
            }

            // MARK: - Developer / Debug Tools
            Section {
                NavigationLink {
                    DebugConsoleView()
                } label: {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 13))
                            Text("디버그 로그 콘솔")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Spacer()
                        Text("\(debugLog.lines.count)개 로그")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.0, green: 0.78, blue: 0.78))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.0, green: 0.78, blue: 0.78).opacity(0.12), in: Capsule())
                    }
                }
            } header: {
                Text("진단 및 개발자 도구")
                    .font(.system(size: 12, weight: .bold))
            }

            // MARK: - App Information
            Section {
                HStack {
                    Text("앱 이름")
                        .font(.system(size: 13))
                    Spacer()
                    Text("BusIsland")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                HStack {
                    Text("버전")
                        .font(.system(size: 13))
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("빌드 번호")
                        .font(.system(size: 13))
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("지원 기능")
                        .font(.system(size: 13))
                    Spacer()
                    Text("Dynamic Island + Live Activity")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("앱 정보")
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshState() }
        .alert("저장 완료", isPresented: $savedBanner) {
            Button("확인", role: .cancel) { dismiss() }
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
