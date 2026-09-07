# 햇살좌석 (SunSeat)

버스 탑승 직전 3초 안에 "어느 쪽 창가에 앉아야 그늘/볕이 좋은지"만 알려주는 단일 목적 앱.

Claude Design 핸드오프(`FLUTTER_HANDOFF.md`, `햇살좌석 앱.dc.html`)를 기반으로 구현한 Flutter 앱입니다.

## 실행

API 키(카카오, TAGO)를 쓰려면 먼저 로컬 시크릿 파일을 채운다 (전부 gitignored — 저장소엔 `.example` 템플릿만 있음):

```bash
cp secrets/dart_defines.example.json secrets/dart_defines.json          # 값 채우기
cp android/app/secrets.properties.example android/app/secrets.properties # 값 채우기
cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig     # 값 채우기 (iOS 빌드 시에만 필요)

flutter pub get
flutter run --dart-define-from-file=secrets/dart_defines.json
```

키 없이 `flutter run`만 해도 앱은 뜨지만, 카카오 로그인은 게스트 모드로만 동작합니다.

## 아직 채워야 하는 것

### 카카오 로그인 — ✅ 키 연결 완료
네이티브 앱 키를 3군데(Dart dart-define / Android manifest / iOS Info.plist)에 자동으로
흘려보내도록 연결했습니다. `secrets/` 아래 로컬 파일만 채우면 실제로 로그인이 동작합니다.
(`android/app/secrets.properties`, `ios/Flutter/Secrets.xcconfig`, `secrets/dart_defines.json`)

### 지도 SDK — WebView + JS SDK 뼈대 완성, 실제 지도 화면엔 아직 미연결
`map` 화면(`lib/screens/map_screen.dart`)은 여전히 도로 그리드 + 건물 블록을 직접
그린 플레이스홀더입니다. 실제 카카오맵을 붙이는 재사용 컴포넌트는 만들어뒀습니다:

- `lib/widgets/kakao_map_view.dart` — `webview_flutter`로 `assets/map/kakao_map.html`
  (카카오맵 JavaScript SDK)을 로드하는 위젯. `KakaoMapView(lat: ..., lng: ...)`로 바로 쓸 수 있음.
- `lib/config/kakao_js_config.dart` — JS 키 설정 (다른 키들과 동일하게
  `secrets/dart_defines.json`의 `KAKAO_JS_KEY`로 주입, JS 키는 **네이티브 앱 키와 다른 키**).

**아직 실제 `map` 화면에 연결하지 않은 이유**: 지금 `RouteDir`엔 정류장 위경도 좌표가
없어서 (표시용 정류장 이름만 있음) 실제 지도 위에 정확한 경로를 그릴 수가 없습니다.
좌표가 생기기 전까지 `KakaoMapView`를 끼워 넣으면 위치가 안 맞는 지도만 뜨게 됩니다.
좌표는 TAGO API(정류소 조회)나 카카오 로컬 API로 채울 수 있는데, 둘 다 아직 실제
엔드포인트를 검증 못 했습니다 — 진행하려면 알려주세요.

**당신이 해야 할 것 (JS 키 발급 시)**:
1. 카카오 디벨로퍼스 → 내 애플리케이션 → 앱 키에서 **JavaScript 키** 발급 (네이티브 키와 별개)
2. 플랫폼 → Web → 사이트 도메인에 `https://appassets.androidplatform.net` 등록
   (Android WebView가 앱 내 HTML을 서빙할 때 쓰는 가상 도메인)
3. iOS는 `loadFlutterAsset`이 실제로 어떤 오리진을 쓰는지 이 세션에서 기기로 확인하지
   못했습니다 — iOS 빌드 시 등록 도메인을 다시 확인해야 할 수 있습니다.
4. `secrets/dart_defines.json`에 `KAKAO_JS_KEY` 채우기

### 노선/정류장 데이터 — API 스펙 확정, 실제 연결은 아직
`lib/models/route.dart`의 6개 노선은 아직 시드 데이터 그대로입니다 (AppState는 이걸 계속 씀).
`lib/services/tago_bus_service.dart` / `lib/models/tago.dart`는 이제 **공식 문서 기준으로
확정**되어 있습니다 — 사용자가 활용신청 승인 후 받은
"오픈API활용가이드_국토교통부(TAGO)_버스노선정보v1.0.docx"를 그대로 반영했고,
`getRouteNoList`는 실제 호출로도 성공(`resultCode 00`)을 확인했습니다.

- base URL 1개, 오퍼레이션 4개(`getRouteNoList`/`getRouteAcctoThrghSttnList`/
  `getRouteInfoIem`/`getCtyCodeList`) 전부 같은 `BusRouteInfoInqireService` 아래에 있습니다.
- `설정 → 개발자용 → TAGO API 테스트` 화면(또는 URL을 브라우저 주소창에 직접 붙여넣기)으로
  실제로 확인 가능합니다.
- **다음 단계**: `getCtyCodeList`로 도시코드 전체 목록을 받아서, 지금 시드 데이터의
  6개 노선(9401/9404/3401/1550/140/472)이 각각 어느 cityCode에 등록돼 있는지 찾아야
  `AppState`가 시드 대신 실제 API를 쓰도록 연결할 수 있습니다. 특히 9401/3401/1550 같은
  광역·직행좌석버스는 서울이 아니라 실제 운행 지자체(성남시 등) 코드일 가능성이 높습니다.
- 정류소 좌표(`gpslati`/`gpslong`)까지 확보되면 `RouteDir.bearing`(진행 방위)도 하드코딩
  대신 기점→종점 좌표로 실제 계산할 수 있게 됩니다 — 지도(`KakaoMapView`) 연결의 전제조건이기도 합니다.

### 기타
- 위치: `geolocator`로 실제 GPS 좌표를 가져오지만, 좌표→정류장 매칭(역지오코딩)은
  TOPIS 연동 전까지는 하드코딩된 문구를 씁니다.
- AR: `flutter_compass` + `camera`를 실제로 사용합니다. 센서/카메라가 없는
  환경(시뮬레이터 등)에서는 자동으로 드래그 시뮬레이션으로 대체됩니다.
- 이 샌드박스에는 Android/iOS 네이티브 SDK가 없어 `flutter analyze` / `flutter test`까지만
  검증했습니다. 실제 기기·에뮬레이터에서 `flutter run`으로 골든 패스를 확인해 주세요.

## 구조

```
lib/
  config/      카카오 앱 키 등 환경 설정
  logic/       태양 방위/고도, 좌석 판정, 구간 일사 — 순수 함수
  models/      노선/즐겨찾기/유저 데이터 모델
  services/    카카오 로그인, 위치, 즐겨찾기 저장
  state/       AppState (Provider ChangeNotifier) — 화면 전환 포함
  screens/     13개 화면
  theme/       색·타이포·스페이싱 토큰
  widgets/     커스텀 페인터(태양 궤적/좌석 지도/경로 지도), 공용 컴포넌트
```
