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

### 노선/정류장 데이터 — 실시간 TAGO 검색으로 교체 완료 (⚠️ 실기기 미검증)
홈 화면 검색이 더 이상 6개 시드 데이터를 안 씁니다. 번호를 입력하고 검색을 누르면:

1. `TagoBusService.findRouteNationwide` — 도시코드 전체를 훑어 그 번호가 등록된
   도시/routeId를 전부 찾고 (사람이 도시를 몰라도 됨)
2. `TagoRouteRepository.search` — 찾은 routeId마다 `getRouteAcctoThrghSttnList`로
   실제 정류장+좌표를 받아서, 상행/하행(`updowncd`)별로 `RouteDir`을 조립하고
   (`RouteDir.bearing`도 이제 좌표 2개로 실제 계산 — `lib/logic/geo.dart`)
3. 결과를 `RouteCache`(`shared_preferences`)에 저장 — 같은 노선을 또 검색하거나
   앱을 다시 켰을 때 네트워크를 안 기다리게.

정류장 좌표는 `RouteDir.stopCoords`에 `stops`와 같은 인덱스로 저장됩니다
(`GeoPoint?`, 좌표가 없으면 null) — 지도 연결과 근접 정류장 계산 둘 다 이 필드를 씁니다.

시드 데이터(`kSeedRoutes`)는 "가까운 정류장" 예시 칩과 오프라인 대체용으로만
남아있고, 좌표가 없어(`stopCoords`가 빈 리스트) 지도·근접 정류장 계산에서는
자동으로 제외됩니다.

**아직 실기기에서 못 본 부분**: `getRouteNoList` 자체는 브라우저로 실제 성공을
확인했지만, 여러 도시 순회(`findRouteNationwide`) → 정류소 조회 → 방향 분리 →
결과 화면까지 이어지는 전체 흐름은 `flutter analyze`/`flutter test`로 타입/구조만
검증했고 실제 기기에서 눌러본 적은 없습니다. 특히:
- `updowncd`로 상행/하행을 정확히 나눌 수 있는지 (문서엔 옵션 필드라 안 올 수도 있음)
- 소요시간(`durationMin`)은 TAGO가 안 줘서 정류장 수 기반 추정치입니다 — 실제 값 아님
- 전국 도시(~200개) 순회라 첫 검색이 몇 초 걸릴 수 있습니다 (동시 8개씩 처리, 캐시되면 이후엔 즉시)
- **버스 번호는 전국적으로 고유하지 않습니다.** "100번"처럼 흔한 번호는 여러
  도시에 동시에 존재할 수 있는데, `findRouteNationwide`는 같은 번호로 잡힌
  도시들을 전부 하나의 `BusRoute`로 합쳐버립니다. 서로 무관한 노선의 방면들이
  한 노선처럼 섞여 보일 수 있다는 뜻 — 사용자가 흔한 번호를 검색했을 때 방면
  목록이 이상하게 많거나 안 맞으면 이 때문일 가능성이 높습니다. (도시별로
  구분해서 고르게 하려면 방면 선택 UI를 도시 단위로 바꿔야 하는데, 이번
  세션에서는 손대지 않았습니다.)

### 근접 정류장 — 두 경로로 구현, 신뢰도가 다릅니다

**1) 방면 안의 가장 가까운 정류장 — ✅ 검증된 데이터로 계산.**
`구간 지정` 화면의 "가까운 정류장으로" 버튼과 정류장 목록의 거리 캡션은 이제
진짜 계산값입니다: `geolocator`의 실제 GPS 좌표와, 위에서 검증된
`getRouteAcctoThrghSttnList` 좌표를 하버사인 공식(`lib/logic/geo.dart`의
`haversineMeters`)으로 비교해 가장 가까운 인덱스를 고릅니다
(`AppState.nearestStop`). 좌표가 없는 노선(시드 데이터)이거나 위치를 못 얻으면
예전처럼 "두 번째 정류장"으로 조용히 대체합니다.

**2) 홈 화면 "가까운 정류장" 캡션 — ⚠️ 미검증 API.**
노선을 고르기 전, 홈 화면 상단 캡션(현재 위치 주변 아무 정류소)은
`lib/services/tago_station_service.dart`(`TagoStationService`)가 새로
붙었습니다. TAGO 정류소정보조회 서비스(`BusSttnInfoInqireService`)의
`getCrdntPrxmtStaionList`(좌표기반근접정류소목록조회)를 쓰는데, 이건 버스노선정보
서비스(`BusRouteInfoInqireService`)와 달리 **공식 문서로 확인하지 못했습니다** —
일반적으로 알려진 필드명(`gpsLati`/`gpsLong`/`nodeid`/`nodenm`/...)을 그대로
반영했을 뿐입니다. 진행하기 전에 브라우저 주소창에 아래 URL을 발급받은
서비스키로 채워 붙여넣어 `resultCode: "00"`이 오는지 먼저 확인해 주세요:

```
https://apis.data.go.kr/1613000/BusSttnInfoInqireService/getCrdntPrxmtStaionList?serviceKey=<발급받은 키>&_type=json&gpsLati=37.498&gpsLong=127.028&numOfRows=5&pageNo=1
```

(좌표는 강남역 근처 예시입니다.) 응답이 다른 필드명으로 오면
`TagoNearbyStation.fromJson`(`lib/models/tago.dart`)의 후보 키 목록만 고치면
됩니다. 실패해도 앱은 멈추지 않고 캡션이 "위치 아이콘을 눌러 확인" 문구로
조용히 대체됩니다 (`AppState._loadNearestStation`).

### 지도 SDK — 실제 카카오맵을 `map` 화면에 연결 완료 (⚠️ JS 키 없으면 플레이스홀더)
`map` 화면(`lib/screens/map_screen.dart`)은 이제 조건부로 두 가지 중 하나를 씁니다:

- **JS 키가 설정돼 있고 + 현재 방면에 좌표 있는 정류장이 하나라도 있으면** →
  `KakaoMapView`(`lib/widgets/kakao_map_view.dart`)로 실제 카카오맵을 띄우고,
  `assets/map/kakao_map.html`의 `setStops()`로 정류장마다 마커를 찍습니다.
- **그 외(JS 키 없음 / 좌표 없는 시드 데이터 등)** → 기존 도로 그리드
  플레이스홀더(`RouteMapPainter`)로 조용히 대체 — 화면이 깨지지 않습니다.

**JS 키를 쓰기 위해 콘솔에서 해야 할 것** (2026-09 기준 — 카카오 디벨로퍼스가
개편돼서 예전 경로 `플랫폼 → Web → 사이트 도메인`은 더 이상 없습니다):

1. **JavaScript 키 발급/확인**: 앱 관리 → `앱` → **`플랫폼 키`** → 스크롤해서
   **`JavaScript 키`** 섹션 (네이티브 앱 키·REST API 키와 각각 다른 키다)
2. **도메인 등록**: 같은 `JavaScript 키` 카드 안의 **`JavaScript SDK 도메인`** 에
   `https://appassets.androidplatform.net` 추가
   (Android WebView가 앱 내 asset을 서빙할 때 쓰는 가상 도메인)
3. **카카오맵 API 활성화**: 2026-07-21부터 이용 절차가 바뀌어서, 도메인 등록만으로는
   부족하고 앱 관리 페이지에서 카카오맵 API를 활성화해야 합니다. 무료 쿼터는
   **개발자 계정 기준 첫 번째로 활성화한 앱에만** 제공되므로, 다른 앱에서 이미
   카카오맵을 켠 적이 있다면 이 앱은 비즈월렛 연결(유료 API)이 필요할 수 있습니다.
4. `secrets/dart_defines.json`의 `KAKAO_JS_KEY` 채우기 (gitignored — 저장소엔 안 올라감)

iOS는 `loadFlutterAsset`이 실제로 어떤 오리진을 쓰는지 확인하지 못했습니다 —
iOS 빌드 시 등록할 도메인을 다시 확인해야 할 수 있습니다.

> 위 콘솔 경로/정책은 검색 결과 기준으로만 확인했고 공식 문서를 직접 열어보진
> 못했습니다 (샌드박스에서 `developers.kakao.com` 접근 차단). 화면이 다르면
> 카카오 디벨로퍼스 공지를 우선하세요.

이 세션도 카카오맵 JS SDK 자체를 실기기에서 눌러보진 못했습니다 — WebView 로딩,
마커 타이밍(SDK 로드 완료 전에 `setStops`가 불릴 수 있어 500ms 뒤 한 번 더
부르도록 방어했습니다), Android/iOS 도메인 등록까지 실기기 확인이 필요합니다.

### 기타
- 위치: `geolocator`로 실제 GPS 좌표를 가져옵니다. 좌표→정류장 매칭은 위
  "근접 정류장" 절 참고 — 방면 안에서는 검증된 좌표로 실제 계산되고, 노선을
  고르기 전 홈 화면 캡션만 미검증 API를 씁니다.
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
