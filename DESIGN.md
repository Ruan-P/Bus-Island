# BusIsland 디자인 브리프

외부 디자인 툴(Figma 등)용. 이 문서는 구현이 아니라 **목표 구조와 화면 규칙**만 적는다.

---

## 1. 제품

서울·경기 버스 **하차 알림**. 핵심은 앱 목록이 아니라 iPhone **Dynamic Island + Live Activity**.

대상 지역: 안양 · 의왕 · 군포 (TAGO 정류소 + GBIS/TAGO 도착).

---

## 2. 지금 구조의 문제

현재 홈은 **노선 먼저**다.

```
1. 노선 검색
2. 그 노선의 승차 정류장
3. 하차 정류장
```

실제 이용은 반대다. 사람은 정류장에 서 있고, 그다음에 “여기 뭐가 오나”를 본다.

---

## 3. 목표 흐름 (정거장 우선)

```
1. 승차 정류장
   GPS 근처 / 지도 / 이름 검색
        ↓
2. 이 정류장에 오는 버스
   도착 예정 노선 리스트 (가까운·곧 오는 순)
   (번호 직접 검색은 보조)
        ↓
3. 하차 정류장
   선택한 노선에서 승차 이후 정류장만
        ↓
4. Live Activity 시작
   Island에 승차/하차 + 남은 정거장
```

이미 있는 API와 맞출 것:

| 단계 | 기존 동작 |
|------|-----------|
| 승차 선택 | `loadNearbyStations` / 지도 / 이름 검색 → `selectNearbyStation` |
| 도착 버스 | `selectNearbyStation`이 `routes(at: stationId)`로 `routeResults` 채움 |
| 노선 확정 | `selectRoute` — 승차가 그 노선에 있으면 유지 |
| 하차 | `destinationCandidates` (승차 순번 이후만) |

홈에 정류장 100개를 펼치지 말 것. 검색·피커 화면으로 고른다.

---

## 4. 인앱 화면

### 4.1 홈 (스크롤 카드)

항상 보이는 것:

- **여정 요약** — 승차 → 노선 → 하차 칩 3개. 미선택은 흐리게.
- **1. 승차 정류장** — GPS / 지도 / 이름 검색. 노선 없이도 가능.
- 설정(기어). 디버그 콘솔은 설정 안 또는 숨김.

조건부:

- 승차 선택 후 → **2. 이 정류장에 오는 버스**
- 승차+노선 후 → **3. 하차 정류장**
- 세 가지 다 되면 → **알림 시작**
- 추적 중 → 히어로 카드 (갱신 / 종료). 승차 대기 vs 탑승 후를 구분.

### 4.2 피커 (푸시)

- 근처/이름 정류장 검색 리스트
- 도착 버스 리스트 (노선번호 + 방면 + 곧 도착이면 강조)
- 하차 정류장 검색 리스트 (순번·이름)

홈에 긴 `ForEach` 금지.

### 4.3 카피

짧게. 예:

- `1. 승차 정류장`
- `2. 이 정류장에 오는 버스`
- `3. 하차 정류장`
- `번호로 직접 찾기` (2번의 보조)

쓰지 말 것: `1. 노선 검색 및 선택`을 첫 단계로.

---

## 5. 색

Island·락스크린·인앱에서 같은 의미.

| 의미 | 역할 | 제안 |
|------|------|------|
| 승차 / 승차까지 남은 수 | cool | teal / cyan / mint |
| 하차 / 하차까지 남은 수 | warm | orange |
| 노선 | identity | blue 또는 흰 글자 |
| 위험(1정거장) | alert | 하차 쪽만 더 강하게 |

숫자 두 개면 **승차 남은 수 ≠ 하차 남은 수** 색을 반드시 다르게.

---

## 6. Live Activity / Dynamic Island

참고: [HIG Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities), [ContainerRelativeShape](https://developer.apple.com/documentation/swiftui/containerrelativeshape)

### 규칙

- 캡슐 **안쪽 여백** 필수. 긴 정류장명이 검은  pill 끝에 붙거나 잘리면 안 됨.
- `ContainerRelativeShape` + padding으로 컨테이너 모양을 따르고 글자는 inset.
- Expanded leading/trailing은 카메라 옆 슬롯 → `.largeTitle` 금지. `.title2` / `.title3`까지.
- 긴 한글: `lineLimit(1)` + `minimumScaleFactor`. 2줄로 캡슐을 키우지 말 것.
- 이모지 대신 `bus.fill`.
- 같은 숫자를 여러 영역에 반복하지 말 것.

### 영역

| 영역 | 내용 |
|------|------|
| Compact leading | 버스 아이콘 + 노선 |
| Compact trailing | 하차까지 남은 수 (orange) |
| Minimal | 하차까지 남은 수 |
| Expanded leading | 아이콘 + 노선 (큰 타입, 여백) |
| Expanded trailing | 지금 국면의 핵심 숫자 (탑승 전이면 승차까지 / 탑승 후면 하차까지) |
| Expanded bottom | 한 줄씩 `승차 이름  N` / `하차 이름  N` |
| Lock Screen | 같은 정보, 높이 여유 있음. 여백 + ContainerRelativeShape |

표시 데이터: `routeNumber`, `boarding`, `destination`, `boardingRemainingStops`, `remainingStops`.

---

## 7. 정보 우선순위

한눈에:

1. 하차까지 몇 정거장 (또는 승차 대기면 승차까지)
2. 노선
3. 하차 정류장 이름
4. 승차 정류장 이름

Island compact는 1+2만.

---

## 8. 구현하지 말 것 (이 문서 범위)

- 서울시 API / Kakao SDK
- App Store 서명
- 홈에 전체 정류장 스크롤 리스트
- 노선 검색을 1단계로 되돌리기

---

## 9. 검수

- [ ] 홈 첫 카드가 승차 정류장인가
- [ ] 정류장 고른 뒤에야 도착 버스가 뜨는가
- [ ] 하차는 승차 이후 정류장만인가
- [ ] Island Expanded에서 긴 이름이 잘리지 않는가 (여백 있음)
- [ ] 승차 수 / 하차 수 색이 다른가
- [ ] 인앱 칩 순서가 승차 → 노선 → 하차인가
