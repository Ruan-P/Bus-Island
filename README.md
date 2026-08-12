# BusIsland

서울 버스 하차 알림을 iPhone Dynamic Island + Live Activity로 보여주는 SwiftUI 프로토타입 앱입니다. 현재는 프로토타입 단계로 서울 버스 API 연동 없이 Mock 데이터로 Live Activity를 시작/업데이트/종료합니다.

## 프로젝트 구조

```
BusIsland/
├── BusIsland/                  # 메인 앱 (SwiftUI)
│   ├── BusIslandApp.swift      # 앱 진입점
│   ├── ContentView.swift       # 데모 UI (시작/업데이트/종료 버튼)
│   ├── Services/               # 서비스 계층
│   │   ├── BusRideProviding.swift    # 라이드 상태 공급자 프로토콜 (API 교체 경계)
│   │   ├── MockBusRideService.swift  # Mock 구현
│   │   └── LiveActivityService.swift # ActivityKit 시작/업데이트/종료
│   └── Assets.xcassets/
├── BusIslandWidget/            # Widget Extension
│   ├── BusIslandWidgetBundle.swift
│   └── BusRideLiveActivity.swift    # Live Activity UI (Compact/Expanded/Minimal/Lock Screen)
├── Shared/Models/              # 앱 + 위젯 공유 모델
│   ├── BusRideActivityAttributes.swift
│   └── BusRideSnapshot.swift
└── BusIsland.xcodeproj
```

## 데모 데이터

- 노선: 3412
- 목적지: 사당역
- 남은 정거장: 4

## Windows 개발 워크플로우

로컬 Windows에서는 Xcode를 실행할 수 없습니다. 소스는 Windows에서 편집하고 빌드는 GitHub Actions의 macOS runner에서 수행합니다.

1. 코드 수정
2. `git push`
3. GitHub Actions의 **iOS Build** 워크플로우가 macOS runner에서 빌드
4. 빌드 산출물 아티팩트 다운로드
   - `BusIsland-unsigned.ipa`: 서명 없는 IPA
   - `BusIsland-xcarchive`: 전체 아카이브
5. IPA를 기존 sideloader로 iPhone 설치 후 테스트

## 빌드 설정

- 최소 배포 타깃: iOS 17.0 (Live Activity는 iOS 16.1+ 필요, ActivityContent는 16.2+)
- Swift 6.0 언어 모드
- Xcode 16.2 (CI 고정), macOS runner: `macos-15`
- 빌드/아카이브는 `CODE_SIGNING_ALLOWED=NO`로 서명 없이 수행

`NSSupportsLiveActivities`는 앱 `Info.plist`에 포함되어 있어 설정에서 Live Activities를 허용하면 Dynamic Island/잠금 화면에 표시됩니다. 잦은 업데이트(Frequent Updates)는 아직 사용하지 않으며, 필요하면 `NSSupportsLiveActivitiesFrequentUpdates`를 추가해야 합니다.

## Apple 서명과 IPA 설치

GitHub Actions는 **서명 없는** IPA를 생성합니다. 서명 없이 iPhone에 설치하려면 sideloader(예: AltStore, Sideloadly, SideStore 등)가 설치 시 자신의 Apple ID로 재서명합니다.

App Store 배포를 원하면 다음이 필요하며 현재 구현 범위가 아닙니다:

- Apple Developer Program 멤버십
- App Store Connect 앱 등록
- 배포 인증서 + Provisioning Profile
- `DEVELOPMENT_TEAM` 설정과 코드 서명 활성화

이 부분을 CI에 넣을 때는 시크릿(인증서, 프로파일) 관리가 필요하므로 현재 단계에서는 README로만 안내합니다.

## 다음 단계

- 서울 버스 공공데이터 API 연동 (`BusRideProviding` 구현 교체)
- 위치 기반 하차 알림
- Live Activity 갱신 전략 (주기적 업데이트, push token 기반)
