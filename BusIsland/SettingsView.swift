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
                    HStack(spacing: 6) {
                        Text("🔑")
                            .font(.system(size: 13))
                        Text("API KEY STATUS")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                    }
                    Spacer()
                    Text(usingBaked ? "[BUILT-IN KEY]" : (APIKeyStore.shared.hasServiceKey ? "[CUSTOM USER KEY]" : "[NO KEY]"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(usingBaked ? Color.secondary : (APIKeyStore.shared.hasServiceKey ? Color(red: 0.25, green: 0.55, blue: 1.0) : Color.red))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((usingBaked ? Color.secondary : (APIKeyStore.shared.hasServiceKey ? Color(red: 0.25, green: 0.55, blue: 1.0) : Color.red)).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
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
                        Text("💾")
                            .font(.system(size: 12))
                        Text("SAVE NEW KEY")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.25, green: 0.55, blue: 1.0))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(serviceKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !usingBaked && APIKeyStore.shared.hasServiceKey {
                    Button(role: .destructive) {
                        APIKeyStore.shared.serviceKey = nil
                        serviceKey = ""
                        refreshState()
                    } label: {
                        Text("REMOVE STORED KEY")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity)
                    }
                }
            } header: {
                Text("◆ GBIS / TAGO API CONFIG")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
            } footer: {
                Text("공공데이터포털(data.go.kr)에서 발급받은 버스 오픈API 인증키(Decoding / Encoding)를 입력해 주세요.")
                    .font(.system(size: 10, design: .monospaced))
            }

            // MARK: - Developer / Debug Tools
            Section {
                NavigationLink {
                    DebugConsoleView()
                } label: {
                    HStack {
                        HStack(spacing: 6) {
                            Text("📟")
                                .font(.system(size: 13))
                            Text("DEBUG LOG CONSOLE")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                        }
                        Spacer()
                        Text("\(debugLog.lines.count) LINES")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 0.15, green: 0.85, blue: 0.70))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.15, green: 0.85, blue: 0.70).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            } header: {
                Text("◆ DEV & DIAGNOSTIC")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
            }

            // MARK: - App Information
            Section {
                HStack {
                    Text("NAME")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Spacer()
                    Text("타섬 (BusIsland)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                HStack {
                    Text("VERSION")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("BUILD")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("DISPLAY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Spacer()
                    Text("Dynamic Island + Live Activity")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("◆ SYSTEM INFO")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
            }
        }
        .navigationTitle("SETTINGS")
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
