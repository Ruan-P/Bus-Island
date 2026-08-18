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

## 앱 아이콘 구성과 재설치 검증

unsigned IPA의 아이콘은 CI archive에서 **Asset Catalog 컴파일 결과**로 결정됩니다.

- 아이콘의 단일 소스는 `BusIsland/Assets.xcassets/AppIcon.appiconset`이고, `CFBundleIconName = AppIcon`은 (수동 plist가 아니라) `ASSETCATALOG_COMPILER_APPICON_NAME` 빌드 설정이 생성한 값을 사용합니다.
- `.app` 루트에 PNG를 복사해 아이콘을 우회 패키징하는 방식은 **사용하지 않습니다**.
- CI가 `Assets.car` 존재, 최종 `Info.plist`의 아이콘 키, `.app` 루트의 아이콘 PNG 부재를 검증합니다.
- Widget Extension의 AppIcon 세트(`BusIslandWidget/Assets.xcassets/AppIcon.appiconset`)는 홈 화면 앱 아이콘을 결정하지 않으며, 메인 타깃의 세트와 같은 원본으로 정리해 둡니다.

아이콘 변경이 홈 화면에 반영되지 않을 때에는 SpringBoard/Sideloader 캐시 문제일 수 있으므로 아래 절차로 확인합니다.

1. 기존 BusIsland 앱을 iPhone에서 **완전히 삭제**합니다.
2. 홈 화면과 Spotlight에서 기존 아이콘 캐시가 사라졌는지 확인합니다.
3. 새 CI artifact(`BusIsland-unsigned.ipa`)를 다운로드합니다.
4. sideloader로 재서명·설치합니다.
5. 그래도 아이콘이 이전 이미지라면 **bundle identifier를 임시 변경한 테스트 빌드**로 원인을 분리합니다.
   - 새 아이콘이 나오면 → 설치 캐시/앱 교체 문제입니다.
   - 새 아이콘도 안 나오면 → archive/Asset Catalog 문제입니다.
6. 원인 확인 후 bundle identifier를 원래 값(`com.busisland.BusIsland`)으로 복원하고 기존 앱 삭제 → 재설치로 마무리합니다.

## 한계 (서버리스)

- 앱이 완전히 종료되면 Live Activity 숫자 자동 갱신이 멈출 수 있음  
- 백그라운드 지속 갱신/푸시 업데이트는 추후 APNs 서버 필요  
- Mock 버튼 데모는 유지되어 있으나 메인 UI는 GBIS 실데이터 흐름  

## 다음 단계

- 위치 기반 근처 정류장  
- 탑승 차량(번호판) 지정 추적  
- Live Activity push token 갱신  
- 백그라운드 위치/BGTask 폴링  
