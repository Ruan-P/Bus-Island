import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var serviceKey: String = APIKeyStore.shared.serviceKey ?? ""
    @State private var savedBanner = false

    var body: some View {
        Form {
            Section {
                SecureField("serviceKey", text: $serviceKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
            } header: {
                Text("공공데이터포털 인증키")
            } footer: {
                Text("data.go.kr에서 경기도 GBIS API(노선/정류소/도착/위치) 활용신청 후 발급받은 Decoding 키를 저장하세요. 키는 Keychain에만 보관됩니다.")
            }

            Section {
                Button("키 저장") {
                    APIKeyStore.shared.serviceKey = serviceKey
                    savedBanner = true
                }
                .disabled(serviceKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if APIKeyStore.shared.hasServiceKey {
                    Button("키 삭제", role: .destructive) {
                        APIKeyStore.shared.serviceKey = nil
                        serviceKey = ""
                    }
                }
            }

            Section("활용신청 대상") {
                Text("경기도_버스정류소 조회")
                Text("경기도_버스노선 조회")
                Text("경기도_버스도착정보 조회")
                Text("경기도_버스위치정보 조회")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .alert("저장됨", isPresented: $savedBanner) {
            Button("확인") { dismiss() }
        } message: {
            Text("인증키가 Keychain에 저장되었습니다.")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
