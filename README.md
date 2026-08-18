# BusIsland

경기버스(안양·의왕 등) 하차 알림을 iPhone Dynamic Island + Live Activity로 보여주는 SwiftUI 앱입니다.

**흐름:** (GPS 근처 또는 이름 검색) 정류장 선택 → 경유 노선 선택 → 하차 정류장 선택 → Live Activity 시작 → GBIS 폴링으로 남은 정거장 갱신

## 프로젝트 구조

```
BusIsland/
├── BusIsland/                       # 메인 앱
│   ├── ContentView.swift            # 정류장→노선→하차 UI + ViewModel
│   ├── NearbyStationsMapView.swift  # GPS + MapKit 주변 정류장
│   ├── SettingsView.swift           # 공공데이터포털 serviceKey 입력
│   └── Services/
│       ├── APIKeyStore.swift        # Keychain 키 저장
│       ├── LocationService.swift    # CoreLocation
│       ├── LiveActivityService.swift
│       ├── MockBusRideService.swift # 프로토타입용 Mock (유지)
│       └── Gbis/
│           ├── GbisAPIClient.swift  # GBIS OpenAPI 클라이언트
│           ├── GbisModels.swift
│           └── GbisRideTracker.swift
├── BusIslandWidget/                 # Live Activity UI
├── Shared/Models/                   # 앱+위젯 공유 ContentState
└── BusIsland.xcodeproj
```

## 공공데이터 API (GBIS)

data.go.kr에서 아래 **경기도** API를 활용신청하고, 발급 **Decoding 키**를 앱 설정에 저장합니다.

| 데이터셋 | 용도 |
|---|---|
| 경기도 버스정류소 조회 | 정류장 이름 검색, 정류장 경유 노선 |
| 경기도 버스노선 조회 | 노선 경유 정류장 순서 |
| 경기도 버스도착정보 조회 | 남은 정거장 수 (`locationNo1`) |
| 경기도 버스위치정보 조회 | 도착 API 실패 시 위치 기반 폴백 |

- Base: `https://apis.data.go.kr/6410000/...` (HTTPS)
- 인앱 키 저장: Keychain (`APIKeyStore`)
- 서버 없음 (serverless). 앱이 포그라운드/활성 중 20초 간격 폴링
- 개발 계정 트래픽: 서비스당 일 1,000회 수준 — 폴링 간격 유지 권장

### 사용자 플로우

1. 설정 → serviceKey 저장  
2. **내 주변 정류장 (지도)** 또는 이름 검색으로 탑승 정류장 선택  
3. 정류장 선택 → **그 정류장을 지나는 노선 목록** 표시  
4. 노선 선택 → 하차 정류장 선택 (탑승 정류장 이후 순번)  
5. Live Activity 시작 → Dynamic Island에 노선/목적지/남은 정거장  

### 지도

- **Apple MapKit** 사용 (외부 SDK 없음, Windows 소스 + CI 빌드에 적합)
- Kakao Maps SDK는 CocoaPods/네이티브 바이너리 의존이 커서 현재 범위에서 제외
- 정류장 좌표는 GBIS `getBusStationAroundList` (x=경도, y=위도, WGS84)  


## Windows 개발 워크플로우

로컬 Windows에서는 Xcode를 실행할 수 없습니다. 소스는 Windows에서 편집하고 빌드는 GitHub Actions macOS runner에서 수행합니다.

1. 코드 수정  
2. `git push`  
3. GitHub Actions **iOS Build**  
4. artifact 다운로드 (`BusIsland-unsigned.ipa`)  
5. sideloader로 iPhone 설치 후 테스트  

## 빌드 설정

- 최소 배포 타깃: iOS 26.0 (iOS 26 전용 Liquid Glass API `glassEffect` / `GlassEffectContainer` 사용)
- Swift 6.0
- Xcode 26.3 (CI), runner: `macos-15`
- `CODE_SIGNING_ALLOWED=NO` unsigned 빌드
- `NSSupportsLiveActivities` = true  

## Apple 서명과 IPA 설치

GitHub Actions는 **서명 없는** IPA를 만듭니다. sideloader가 설치 시 Apple ID로 재서명합니다.

App Store 배포·인증서·프로파일은 현재 범위 밖입니다.

## 한계 (서버리스)

- 앱이 완전히 종료되면 Live Activity 숫자 자동 갱신이 멈출 수 있음  
- 백그라운드 지속 갱신/푸시 업데이트는 추후 APNs 서버 필요  
- Mock 버튼 데모는 유지되어 있으나 메인 UI는 GBIS 실데이터 흐름  

## 다음 단계

- 위치 기반 근처 정류장  
- 탑승 차량(번호판) 지정 추적  
- Live Activity push token 갱신  
- 백그라운드 위치/BGTask 폴링  
