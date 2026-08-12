# BusIsland 개발 현황

마지막 갱신: 2026-08-12

## 완료

- Live Activity 프로토타입 (Mock) + CI unsigned IPA (run #5 그린)
- **GBIS(경기도 버스) 연동**
  - 정류장 검색 → 경유 노선 선택 → 하차 정류장 선택 → LA 시작
  - GPS 근처 정류장 + Apple MapKit 지도
  - 인앱 serviceKey (Keychain)
  - 20초 폴링 (도착 API `locationNo1` 우선, 위치 API 폴백)
- Dynamic Island UI 유지 (Compact/Expanded/Minimal/Lock)

## 사용 전 준비

1. data.go.kr에서 경기도 GBIS 4종 활용신청  
   - 정류소 조회 / 노선 조회 / 도착정보 / 위치정보  
2. Decoding 키를 앱 설정에 저장  
3. push → CI → IPA → sideload  

## 다음

- 실기기에서 안양·의왕 정류장으로 E2E 테스트  
- 근처 정류장(위치)  
- 앱 종료 후에도 갱신하려면 push 서버  
