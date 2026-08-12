# BusIsland 개발 현황 및 다음 단계

마지막 갱신: 2026-08-12
작성 시점 커밋: `d06d1a0` (main), CI run #1/#2 실패

## 완료된 작업

- 프로젝트 스캐폴드 완성 (Windows에서 작성, macOS CI에서 빌드하는 구조)
  - `BusIsland/` 메인 앱 (SwiftUI + @Observable ViewModel)
  - `BusIslandWidget/` Widget Extension (Live Activity 전담)
  - `Shared/Models/` 앱+위젯 공유 모델
  - `BusIsland.xcodeproj` 수작업 생성 (2개 타깃, 공유 scheme 포함)
- Live Activity 구현: 시작 / 업데이트 / 종료, Compact·Expanded·Minimal·Lock Screen UI
- Mock 서비스 계층 (`BusRideProviding` 프로토콜 + `MockBusRideService`)
- 데모 데이터: 노선 3412 / 사당역 / 남은 4정거장
- GitHub Actions workflow (`ios-build.yml`): unsigned build → archive → unsigned IPA artifact
- README (Windows 워크플로우, 서명 관련 안내)
- AGENTS.md에 코드 맵/구조/컨벤션 통합
- public repo `Ruan-P/Bus-Island` 생성·연결, main 푸시 완료

## CI 빌드 실패 원인 (확정)

워크플로우는 checkout/Xcode 선택까지 성공, `xcodebuild build` 단계에서 실패.
실패 로그 기준 (run 31584270141, Xcode 16.2, iOS 18.2 SDK, Release-iphoneos):

```
BusIsland/Assets.xcassets: error: No simulator runtime version
from [22F77, 22G86, 23A8464, 23B86, 23C54] available to use with
iphonesimulator SDK version 22C146
```

### 루트 원인

`actool`이 **iphonesimulator SDK(22C146)** 로 에셋 카탈로그를 컴파일하려 했지만,
runner에 설치된 시뮬레이터 런타임 버전이 호환되지 않음.
project.pbxproj에서 `SUPPORTED_PLATFORMS`를 명시하지 않아 기본값
(iphoneos + iphonesimulator)으로 확장됐고, 시뮬레이터용 actool이 실패했다.

### 수정 계획 (미적용, 대기 중)

1. `BusIsland.xcodeproj/project.pbxproj`의 앱·위젯 타깃에
   `SUPPORTED_PLATFORMS = iphoneos;` 추가 → actool이 device 전용으로만 실행.
2. 부수 경고 수정:
   - 위젯 타깃 `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` 참조 제거
     (위젯 자산 카탈로그에 AccentColor 없음).
   - AppIcon single-size 항목에 `"filename": "AppIcon.png"` 추가
     ("unassigned child" 경고 제거).
3. push → CI 재실행으로 검증.

## 다음 단계 (우선순위순)

1. 위 수정 적용 후 CI 그린 확인
2. artifact(IPA) 다운로드 → sideloader로 iPhone 설치 → 실제 기기 QA
3. (이후) 서울 버스 API 구현체를 `BusRideProviding`에 연결

## 참고 (검증 안 된 것)

- Swift 소스의 실제 컴파일 통과 여부는 CI가 돌기 전까지 확인 불가 (Windows에는 Xcode 없음).
  빌드 실패는 컴파일 이전 단계(actool)에서 발생했으므로 Swift 코드의 오류 여부는 아직 미검증.
- 잠금 화면에서의 실제 표시, Dynamic Island 렌더링은 실기기 sideload 후에만 확인 가능.
