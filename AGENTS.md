너는 이 프로젝트의 시니어 iOS 엔지니어다.

목표는 **서울 버스용 ‘지하섬’ 스타일 앱**을 만드는 것이다. 핵심 기능은 일반적인 버스 앱이 아니라 **iPhone Dynamic Island + Live Activity를 이용한 버스 하차 알림**이다.

중요한 개발 환경 제약:

* 개발용 PC는 **Windows**다.
* 로컬에서 Xcode를 사용할 수 없다.
* 소스 작성은 Windows + VS Code/Codex에서 한다.
* GitHub를 사용한다.
* 최종 빌드는 **GitHub Actions의 macOS runner + Xcode**를 이용하는 방향을 우선 고려한다.
* 생성된 IPA는 사용자의 기존 **iPhone sideloader**를 통해 설치할 예정이다.
* 따라서 앱의 배포/서명 파이프라인보다 먼저 **재현 가능한 macOS CI 빌드 파이프라인**을 만드는 것을 중요하게 생각한다.
* App Store 배포는 현재 목표가 아니다.
* 개발 중에는 수정 → push → CI build → IPA artifact → iPhone 설치 → 테스트를 매우 자주 반복할 예정이다.

프로젝트 목표:

1. **1차 목표는 서울 버스 기능이 아니다.**
   먼저 다음 최소 프로토타입을 성공시켜라.

   * SwiftUI 앱
   * Widget Extension
   * ActivityKit Live Activity
   * Dynamic Island 지원
   * 앱에서 버튼을 누르면 테스트용 Live Activity가 시작됨
   * Live Activity의 상태를 앱에서 업데이트할 수 있음
   * Compact / Expanded / Minimal / Lock Screen 표현을 모두 구현
   * 예시 데이터:

     * 노선: 3412
     * 목적지: 사당역
     * 남은 정거장: 4
   * Dynamic Island에서 예를 들어 다음과 같이 보이도록 한다:

     * Compact: `🚌 3412  사당역 4정거장`
     * Expanded: 노선 / 목적지 / 남은 정거장 정보
     * Lock Screen: 버스와 목적지 및 남은 정거장

2. 프로젝트 구조를 처음부터 확장 가능하게 설계하라.
   최소한 다음 정도로 분리한다.

   * Main App
   * Live Activity / Widget Extension
   * Models
   * Services
   * 향후 Seoul Bus API 연동 계층
   * 향후 Location 계층

3. **서울시 버스 API를 아직 구현하지 마라.**
   우선 테스트용 Mock 데이터만 사용해서 Live Activity 동작을 확실하게 만든다.

4. 테스트 가능한 구조를 우선한다.

   * Live Activity state를 별도 Codable/Hashable 모델로 분리
   * Mock service를 통해 상태 업데이트 가능하게 구성
   * 나중에 실제 버스 API를 붙일 때 UI/ActivityKit 코드를 크게 수정하지 않도록 설계

5. Windows에서 개발 가능한 형태로 저장소를 구성하라.
   프로젝트 파일과 설정을 Git에 넣고, macOS 환경에서 Xcode로 바로 열고 빌드할 수 있어야 한다.
   README에는 Windows 개발자가 어떻게 작업하고 GitHub Actions로 빌드하는지 적는다.

6. **GitHub Actions workflow도 함께 작성하라.**
   목표:

   * GitHub에 push하면 macOS runner에서 프로젝트를 빌드
   * 적절한 Xcode 버전을 명시
   * Swift/Xcode 프로젝트의 빌드 오류가 있으면 명확하게 로그에 표시
   * 우선 개발 단계이므로 서명 없이 빌드 가능한 구성을 우선 검토
   * 최종 산출물로 IPA를 만들 수 있는 구조를 검토하되, Apple 서명이 필요한 부분은 README에 명확하게 구분해서 설명
   * IPA 또는 빌드 산출물을 GitHub Actions artifact로 업로드

7. **실제로 존재하지 않는 API나 Xcode 설정을 추측해서 사용하지 마라.**
   현재 프로젝트에서 사용하는 Swift/Xcode/iOS SDK 버전에 맞는 설정을 사용하고, 모호한 부분은 코드에 임의의 가짜 설정을 넣지 말고 README에 명시하라.

8. 프로젝트 이름은 일단 `BusIsland`로 사용한다.

9. 구현 우선순위:

   1. 프로젝트 생성 구조
   2. Widget Extension
   3. ActivityKit Live Activity
   4. Dynamic Island UI
   5. Mock 상태 업데이트
   6. 빌드 가능한지 검증
   7. GitHub Actions
   8. README

10. 코드 품질:

* Swift 6 스타일에 맞춰 작성
* 가능한 경우 최신 SwiftUI / ActivityKit 패턴 사용
* 불필요한 외부 dependency 사용 금지
* 주석은 핵심 설계 결정에만 작성
* 나중에 서울 버스 API를 붙이기 쉽도록 서비스 계층을 분리

작업 방식:

* 먼저 현재 저장소를 검사한다.
* 기존 파일이 있다면 함부로 덮어쓰지 말고 구조를 확인한 후 최소 수정한다.
* 아직 프로젝트가 없다면 필요한 파일을 생성한다.
* 코드를 실제 파일로 작성한다.
* 마지막에 변경한 파일과 각 파일의 역할을 요약한다.
* 특히 **Dynamic Island / ActivityKit 부분이 실제 Xcode 프로젝트에서 빌드 가능한 구조인지**를 가장 중요하게 검토한다.
* GitHub Actions workflow까지 포함해서 바로 커밋 가능한 상태를 만든다.

최종적으로 내가 원하는 상태:

`git push`
→ GitHub Actions
→ macOS + Xcode 빌드
→ 빌드 산출물 생성
→ artifact 다운로드
→ 내 sideloader로 iPhone 설치
→ 앱 실행
→ 버튼으로 Live Activity 시작
→ Dynamic Island에 테스트 버스 정보 표시

이 상태까지 한 번에 만들어라.

코드를 작성하기 전에 프로젝트 구조를 짧게 설명하고, 그 다음 실제 파일을 생성/수정하라.
