import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var serviceKey: String = ""
    @State private var savedBanner = false
    @State private var usingBaked = true

    var body: some View {
        Form {
            Section {
                Text(usingBaked
                     ? "빌드에 기본 API 키가 포함되어 있습니다. 다른 키를 쓰려면 아래에 붙여넣고 저장하세요."
                     : "Keychain에 사용자 키가 저장되어 있습니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                SecureField("serviceKey (Encoding/Decoding 모두 가능)", text: $serviceKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())

                TextField("키 확인용", text: $serviceKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Button {
                    let trimmed = serviceKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    APIKeyStore.shared.serviceKey = trimmed.isEmpty ? nil : trimmed
                    refreshState()
                    savedBanner = true
                } label: {
                    Label("키 저장", systemImage: "key.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(serviceKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !usingBaked {
                    Button("기본 빌드 키로 되돌리기", role: .destructive) {
                        APIKeyStore.shared.serviceKey = nil
                        serviceKey = ""
                        refreshState()
                    }
                } else {
                    Label("기본 키 사용 중 (설정 불필요)", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                }
            } header: {
                Text("GBIS API 인증키")
            } footer: {
                Text("%2F 가 포함된 Encoding 키를 넣어도 자동으로 Decoding 키로 변환합니다. 이중 인코딩(400 오류)을 방지합니다.")
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
                LabeledContent("키 상태", value: usingBaked ? "빌드 기본키" : "사용자 저장키")
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshState() }
        .alert("저장됨", isPresented: $savedBanner) {
            Button("확인") { dismiss() }
        } message: {
            Text("인증키가 적용되었습니다.")
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
