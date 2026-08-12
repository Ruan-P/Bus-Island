# BusIsland 개발 현황 및 다음 단계

마지막 갱신: 2026-08-12
작성 시점 커밋: `ec12d8a` (main), CI run #5 성공

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
- CI 빌드 그린 (run #5, 커밋 `ec12d8a`, Xcode 16.4, iOS 18.5 SDK)
  - `Build (no code signing)` / `Archive (no code signing)` 모두 성공 (`ARCHIVE SUCCEEDED`)
  - 앱 + 위젯 타깃 모두 컴파일·링크, 위젯이 앱에 임베드됨
  - 산출물 artifact 2종 업로드 완료:
    - `BusIsland-unsigned-ipa` (84 KB, sha256 `ed3ff942...`)
    - `BusIsland-xcarchive` (1.1 MB, sha256 `5a998376...`)

## CI 빌드 실패 원인과 수정 (완료)

최초 실패는 `actool`이 **iphonesimulator SDK(22C146, Xcode 16.2)** 로 AppIcon
에셋 카탈로그를 컴파일하려 했지만 runner에 설치된 시뮬레이터 런타임
(22F77/22G86/23A8464/23B86/23C54)과 짝이 맞지 않아 발생.

적용한 수정:

1. `project.pbxproj`에 앱·위젯 타깃 `SUPPORTED_PLATFORMS = iphoneos;` 추가
   → actool이 device 플랫폼으로만 실행.
2. 위젯 타깃 `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` 제거
   (위젯 자산 카탈로그에 AccentColor 없음).
3. AppIcon single-size 항목에 `"filename": "AppIcon.png"` 추가
   ("unassigned child" 경고 제거).
4. 워크플로우 Xcode 16.2 → **16.4** 전환 (iOS 18.5 SDK 22F77, runner 설치
   런타임과 호환) → run #5 그린 확인.

## 다음 단계 (우선순위순)

1. 위 수정 적용 후 CI 그린 확인
2. artifact(IPA) 다운로드 → sideloader로 iPhone 설치 → 실제 기기 QA
   - 앱 실행 → 버튼으로 Live Activity 시작 → Dynamic Island/Lock Screen 표시 확인
3. (이후) 서울 버스 API 구현체를 `BusRideProviding`에 연결

## 참고 (검증 안 된 것)

- 잠금 화면/Dynamic Island의 실제 렌더링은 실기기 sideload 후에만 확인 가능.
- `Validate` 단계에서 "All interface orientations must be supported unless the
  app requires full screen" 경고가 출력되지만 빌드 실패가 아니며, App Store
  배포가 목표가 아니므로 현재 무시. 추후 필요 시 Info.plist에 회전 방향 명시.
