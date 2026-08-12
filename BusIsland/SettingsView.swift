import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var serviceKey: String = ""
    @State private var savedBanner = false
    @State private var hasStoredKey = false

    var body: some View {
        Form {
            Section {
                Text("공공데이터포털(data.go.kr)에서 발급한 Decoding 인증키를 붙여넣으세요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                SecureField("serviceKey 붙여넣기", text: $serviceKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())

                // Also allow plain text paste visibility toggle-free field for easier paste on device
                TextField("키 확인용 (선택)", text: $serviceKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Button {
                    let trimmed = serviceKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    APIKeyStore.shared.serviceKey = trimmed.isEmpty ? nil : trimmed
                    hasStoredKey = APIKeyStore.shared.hasServiceKey
                    savedBanner = true
                } label: {
                    Label(hasStoredKey ? "키 다시 저장" : "키 저장", systemImage: "key.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(serviceKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if hasStoredKey {
                    Label("키가 Keychain에 저장되어 있습니다", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)

                    Button("키 삭제", role: .destructive) {
                        APIKeyStore.shared.serviceKey = nil
                        serviceKey = ""
                        hasStoredKey = false
                    }
                }
            } header: {
                Text("GBIS API 인증키")
            } footer: {
                Text("활용신청: 경기도 버스정류소/노선/도착/위치 조회. 키는 기기에만 저장되며 서버로 보내지 않습니다.")
            }

            Section("활용신청 대상 (data.go.kr)") {
                Text("경기도_버스정류소 조회")
                Text("경기도_버스노선 조회")
                Text("경기도_버스도착정보 조회")
                Text("경기도_버스위치정보 조회")
            }
            .font(.footnote)

            Section("앱 정보") {
                LabeledContent("버전", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                LabeledContent("빌드", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hasStoredKey = APIKeyStore.shared.hasServiceKey
            // Don't prefill secret into plain fields for security; user pastes again if needed.
            if hasStoredKey, serviceKey.isEmpty {
                serviceKey = APIKeyStore.shared.serviceKey ?? ""
            }
        }
        .alert("저장됨", isPresented: $savedBanner) {
            Button("확인") { dismiss() }
        } message: {
            Text("인증키가 저장되었습니다. 이제 주변 정류장/검색을 사용할 수 있습니다.")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
