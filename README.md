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

### 노선/정류장 데이터 — 실시간 TAGO 검색으로 교체 완료 (⚠️ 실기기 미검증)
홈 화면 검색이 더 이상 6개 시드 데이터를 안 씁니다. 번호를 입력하고 검색을 누르면:

1. `TagoBusService.findRouteNationwide` — 도시코드 전체를 훑어 그 번호가 등록된
   도시/routeId를 전부 찾고 (사람이 도시를 몰라도 됨)
2. `TagoRouteRepository.search` — 찾은 routeId마다 `getRouteAcctoThrghSttnList`로
   실제 정류장+좌표를 받아서, 상행/하행(`updowncd`)별로 `RouteDir`을 조립하고
   (`RouteDir.bearing`도 이제 좌표 2개로 실제 계산 — `lib/logic/geo.dart`)
3. 결과를 `RouteCache`(`shared_preferences`)에 저장 — 같은 노선을 또 검색하거나
   앱을 다시 켰을 때 네트워크를 안 기다리게.

시드 데이터(`kSeedRoutes`)는 "가까운 정류장" 예시 칩과 오프라인 대체용으로만 남아있습니다.

**아직 실기기에서 못 본 부분**: `getRouteNoList` 자체는 브라우저로 실제 성공을
확인했지만, 여러 도시 순회(`findRouteNationwide`) → 정류소 조회 → 방향 분리 →
결과 화면까지 이어지는 전체 흐름은 `flutter analyze`/`flutter test`로 타입/구조만
검증했고 실제 기기에서 눌러본 적은 없습니다. 특히:
- `updowncd`로 상행/하행을 정확히 나눌 수 있는지 (문서엔 옵션 필드라 안 올 수도 있음)
- 소요시간(`durationMin`)은 TAGO가 안 줘서 정류장 수 기반 추정치입니다 — 실제 값 아님
- 전국 도시(~200개) 순회라 첫 검색이 몇 초 걸릴 수 있습니다 (동시 8개씩 처리, 캐시되면 이후엔 즉시)

### 지도 SDK — WebView + JS SDK 뼈대 완성, 실제 지도 화면엔 아직 미연결
`map` 화면(`lib/screens/map_screen.dart`)은 여전히 도로 그리드 + 건물 블록을 직접
그린 플레이스홀더입니다. 실제 카카오맵을 붙이는 재사용 컴포넌트는 만들어뒀습니다:

- `lib/widgets/kakao_map_view.dart` — `webview_flutter`로 `assets/map/kakao_map.html`
  (카카오맵 JavaScript SDK)을 로드하는 위젯. `KakaoMapView(lat: ..., lng: ...)`로 바로 쓸 수 있음.
- `lib/config/kakao_js_config.dart` — JS 키 설정 (다른 키들과 동일하게
  `secrets/dart_defines.json`의 `KAKAO_JS_KEY`로 주입, JS 키는 **네이티브 앱 키와 다른 키**).

이제 `RouteDir`에 실제 정류장 좌표가 들어있으니(위 TAGO 연동 참고) `map` 화면에
`KakaoMapView`를 실제로 붙이는 건 남은 작업입니다 — JS 키만 받으면 바로 진행 가능합니다.

**당신이 해야 할 것 (JS 키 발급 시)**:
1. 카카오 디벨로퍼스 → 내 애플리케이션 → 앱 키에서 **JavaScript 키** 발급 (네이티브 키와 별개)
2. 플랫폼 → Web → 사이트 도메인에 `https://appassets.androidplatform.net` 등록
   (Android WebView가 앱 내 HTML을 서빙할 때 쓰는 가상 도메인)
3. iOS는 `loadFlutterAsset`이 실제로 어떤 오리진을 쓰는지 이 세션에서 기기로 확인하지
   못했습니다 — iOS 빌드 시 등록 도메인을 다시 확인해야 할 수 있습니다.
4. `secrets/dart_defines.json`에 `KAKAO_JS_KEY` 채우기

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
