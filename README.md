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

키 없이 `flutter run`만 해도 앱은 뜨지만, 카카오 로그인은 게스트 모드로만 동작하고
노선 검색(TAGO)은 아예 실패합니다.

카카오 키는 용도별로 **세 개가 전부 다른 키**입니다 — 앱 → `플랫폼 키`에서 각각 확인:

| dart-define | 카카오 콘솔 | 쓰는 곳 |
|---|---|---|
| `KAKAO_NATIVE_APP_KEY` | 네이티브 앱 키 | 카카오 로그인 (Android/iOS 네이티브 SDK) |
| `KAKAO_JS_KEY` | JavaScript 키 | 지도 화면 WebView (카카오맵 JS SDK) |
| `KAKAO_REST_API_KEY` | REST API 키 | 좌표→행정구역 (검색 범위 좁히기) |

> ⚠️ **TAGO 서비스키는 반드시 "디코딩" 버전을 넣으세요.** 공공데이터포털은 같은 키를
> Encoding/Decoding 두 형태로 보여주는데, 앱에는 디코딩 버전(`+`, `/`, `=`가 그대로
> 들어있는 쪽)을 넣어야 합니다. `TagoBusService`는 `Uri.replace(queryParameters:)`로
> 요청을 만들고 이게 값을 다시 퍼센트 인코딩하기 때문에, 인코딩 버전(`%2B`, `%2F`,
> `%3D`)을 넣으면 `%252B`처럼 이중 인코딩돼 인증에 실패합니다.
> 반대로 **브라우저 주소창에서 직접 테스트할 때는 인코딩 버전**을 써야 합니다.

## 아직 채워야 하는 것

### 카카오 로그인 — ✅ 키 연결 완료
네이티브 앱 키를 3군데(Dart dart-define / Android manifest / iOS Info.plist)에 자동으로
흘려보내도록 연결했습니다. `secrets/` 아래 로컬 파일만 채우면 실제로 로그인이 동작합니다.
(`android/app/secrets.properties`, `ios/Flutter/Secrets.xcconfig`, `secrets/dart_defines.json`)

### 노선/정류장 데이터 — 실시간 TAGO 검색으로 교체 완료 (⚠️ 실기기 미검증)
홈 화면 검색이 더 이상 6개 시드 데이터를 안 씁니다. 번호를 입력하고 검색을 누르면:

1. `TagoRouteRepository.search` — **현재 위치로 검색 범위를 좁혀가며** 그 번호가
   등록된 도시/routeId를 찾고 (사람이 도시를 몰라도 됨. 아래 "호출 수" 절 참고)
2. 찾은 routeId마다 `getRouteAcctoThrghSttnList`로 실제 정류장+좌표를 받아서
   방면별 `RouteDir`을 조립하고
   (`RouteDir.bearing`도 좌표 2개로 실제 계산 — `lib/logic/geo.dart`)
3. 결과를 `RouteCache`(`shared_preferences`)에 저장 — 같은 노선을 또 검색하거나
   앱을 다시 켰을 때 네트워크를 안 기다리게.

#### ⚠️ 호출 수 — 공개 배포에서 제일 중요한 제약
TAGO는 `cityCode`가 **필수**라 "도시를 모르는 검색"이라는 게 없습니다. 그래서 앱이
도시를 하나씩 물어보는 수밖에 없는데, **호출 수 = 물어본 도시 수**입니다.
전국을 훑으면 검색 한 번에 API가 150~250번 나가고, 개발계정 일일 한도가 보통
1,000건이니 **앱 전체를 통틀어 하루 대여섯 번 검색하면 한도가 끝납니다.**
플레이스토어 배포에는 성립하지 않는 구조라, 범위를 단계적으로 넓히도록 바꿨습니다:

| 단계 | 범위 | 호출 수 |
|---|---|---|
| 1 | 카카오 로컬 API로 좌표 → 행정구역 → 그 도시 | 1~2회 |
| 2 | 못 찾으면 **같은 도(道) 전체** (경기 기준 40개 안팎) | 수십 회 |
| 3 | 그래도 못 찾고 `allowNationwide`면 전국 (마지막 수단) | 150~250회 |

- 2단계가 필요한 이유: 광역버스는 사용자가 서 있는 시가 아니라 **옆 시에 등록**돼
  있을 수 있습니다 (예: 9401은 서울이 아니라 경기 시·군 소속).
  도 판별은 도시코드 앞 2자리로 합니다 (`31010`, `31020` → `31` 경기).
- 즐겨찾기 백그라운드 프리페치(`ensureRouteCached`)는 `allowNationwide: false`입니다.
  사용자가 요청하지도 않은 작업이 즐겨찾기 하나당 200번씩 쓰면, 앱을 켜는 것만으로
  하루 한도가 날아갑니다.
- 검색 직전에 위치를 먼저 확보합니다(`submitSearch`). 위치를 못 얻거나 카카오
  REST 키가 없으면 3단계로 바로 갑니다 — 동작은 하되 비싸집니다.

정류장 좌표는 `RouteDir.stopCoords`에 `stops`와 같은 인덱스로 저장됩니다
(`GeoPoint?`, 좌표가 없으면 null) — 지도 연결과 근접 정류장 계산 둘 다 이 필드를 씁니다.

시드 데이터(`kSeedRoutes`)는 "가까운 정류장" 예시 칩과 오프라인 대체용으로만
남아있고, 좌표가 없어(`stopCoords`가 빈 리스트) 지도·근접 정류장 계산에서는
자동으로 제외됩니다.

**✅ 정류소 좌표 확인 완료 (2026-09-07, cityCode 12 / routeId SJB271000805)**:
`getRouteAcctoThrghSttnList`가 `gpslati`·`gpslong`·`nodeord`를 실제로 돌려주는 걸
확인했습니다. 좌표는 **JSON 숫자 타입**으로 오지만 `_pick`이 `toString()`을 거쳐
파싱하므로 문제 없습니다. `updowncd`는 응답에 **없었고**, 그래서 방면 구분은
routeId로만 이뤄집니다 (`_toDirs`의 `upDownCode ?? 0` 폴백이 이 경우를 처리).
즉 **진행 방위(bearing) → 좌석 판정으로 이어지는 핵심 경로가 실제 데이터로 동작**합니다.

**아직 실기기에서 못 본 부분**: `getRouteNoList` 자체는 브라우저로 실제 성공을
확인했지만, 여러 도시 순회(`findRouteNationwide`) → 정류소 조회 → 방향 분리 →
결과 화면까지 이어지는 전체 흐름은 `flutter analyze`/`flutter test`로 타입/구조만
검증했고 실제 기기에서 눌러본 적은 없습니다. 특히:
- ~~`updowncd`로 상행/하행을 정확히 나눌 수 있는지~~ → **✅ 해결됨 (2026-09-07 실제 응답).**
  방면은 `updowncd`가 아니라 **routeId 자체가 다르게** 옵니다. 세종시(cityCode 12)
  `B7`을 조회하면 `SJB271000805`(집현동→비하종점)와 `SJB271000806`(비하종점→집현동)이
  같은 `routeno`로 따로 잡힙니다. `TagoRouteRepository.search`가 routeId마다
  `RouteDir`을 만들기 때문에 이 케이스는 이미 올바르게 처리됩니다
  (`updowncd`가 오는 경우에도 그 안에서 한 번 더 나누므로 양쪽 다 커버).
- 소요시간(`durationMin`)은 TAGO가 안 줘서 정류장 수 기반 추정치입니다 — 실제 값 아님
- 전국 도시(~200개) 순회라 첫 검색이 몇 초 걸릴 수 있습니다 (동시 8개씩 처리, 캐시되면 이후엔 즉시)
- **⚠️ 도시코드 목록에 `11`(서울)이 없습니다.** 2026-09-07 `getCtyCodeList`를 실제로
  호출한 결과, 목록은 오름차순으로 `12, 21, 22, 23, 24, 25, 26, 39, 31010, 31020…`
  으로 시작합니다 — `11`이 있었다면 맨 앞에 나왔어야 하는데 없습니다. 즉
  **서울 시내버스는 이 API로 검색되지 않을 가능성이 높습니다** (서울은 별도로
  서울시 TOPIS/`api.bus.go.kr`가 담당). 확실히 하려면 도시명을 확인해야 하는데
  브라우저에서는 한글이 깨져 보여서 이 세션에서는 끝까지 확정하지 못했습니다
  (앱의 TAGO 테스트 화면은 UTF-8로 제대로 디코딩하니 거기서 보면 됩니다).
  - 없는 도시코드로 조회하면 **에러가 아니라** `resultCode: "00"` + `totalCount: 0`이
    옵니다 — "API가 고장났나?"로 오해하기 쉬우니 주의.
  - 확인된 코드: **`12` = 세종특별자치시** (routeId 접두사 `SJB`, totalCount 135).
  - 시드 데이터(`kSeedRoutes`)의 `140`, `472` 같은 서울 간선/지선 노선은 실제
    검색으로는 못 찾을 수 있습니다.
  - **서울 지원은 하기로 결정됐고 아직 미착수입니다** — 아래 "서울(TOPIS)" 절 참고.
- **버스 번호는 전국적으로 고유하지 않습니다.** "100번"처럼 흔한 번호는 여러
  도시에 동시에 존재할 수 있는데, `findRouteNationwide`는 같은 번호로 잡힌
  도시들을 전부 하나의 `BusRoute`로 합쳐버립니다. 서로 무관한 노선의 방면들이
  한 노선처럼 섞여 보일 수 있다는 뜻 — 사용자가 흔한 번호를 검색했을 때 방면
  목록이 이상하게 많거나 안 맞으면 이 때문일 가능성이 높습니다. (도시별로
  구분해서 고르게 하려면 방면 선택 UI를 도시 단위로 바꿔야 하는데, 이번
  세션에서는 손대지 않았습니다.)

### 서울(TOPIS) — 지원하기로 결정, 미착수 🚧
전국 배포에는 사실상 필수입니다(서울 버스 이용자가 가장 많은데 TAGO엔 서울이
없습니다). 아직 시작하지 않은 이유는 **키가 없고, 이 세션에서 응답을 검증할
방법이 없기 때문**입니다 — 검증 없이 추측으로 짜면
`appassets.androidplatform.net` 때처럼 틀린 코드가 나옵니다.

**필요한 것**: 공공데이터포털 또는 서울열린데이터광장에서 서울 버스노선 API
활용신청 → 서비스키 발급. 발급 후 브라우저/curl로 노선 조회 응답을 한 번
받아보면, 그 응답 모양에 맞춰 붙일 수 있습니다.

**붙일 자리는 이미 준비돼 있습니다**: `TagoRouteRepository.search`가 위치로
도시를 판별하니, "행정구역이 서울이면 TOPIS provider를 쓴다"는 분기를 그
지점에 넣으면 됩니다. `BusRoute`/`RouteDir`은 API 중립적인 모양이라
(정류장 이름 + 좌표 + 진행 방위) 좌석 계산 로직은 그대로 재사용됩니다.

### 근접 정류장 — 두 경로로 구현, 신뢰도가 다릅니다

**1) 방면 안의 가장 가까운 정류장 — ✅ 검증된 데이터로 계산.**
`구간 지정` 화면의 "가까운 정류장으로" 버튼과 정류장 목록의 거리 캡션은 이제
진짜 계산값입니다: `geolocator`의 실제 GPS 좌표와, 위에서 검증된
`getRouteAcctoThrghSttnList` 좌표를 하버사인 공식(`lib/logic/geo.dart`의
`haversineMeters`)으로 비교해 가장 가까운 인덱스를 고릅니다
(`AppState.nearestStop`). 좌표가 없는 노선(시드 데이터)이거나 위치를 못 얻으면
예전처럼 "두 번째 정류장"으로 조용히 대체합니다.

**2) 홈 화면 "가까운 정류장" 캡션 — ⚠️ 1순위 API가 현재 막혀 있어 대체 경로로 동작.**
노선을 고르기 전, 홈 화면 상단 캡션(현재 위치 주변 정류소)은 두 단계로 값을 구합니다
(`AppState._loadNearestStation`):

1. **TAGO 좌표기반 근접 정류소 조회** — `lib/services/tago_station_service.dart`.
   TAGO 정류소정보조회 서비스(`BusSttnInfoInqireService`)의
   `getCrdntPrxmtStaionList`. 전국 아무 정류소나 찾을 수 있는 제대로 된 방법이지만,
   **2026-09-07 실제 호출 결과 이 프로젝트 키로는 동작하지 않습니다**:
   `NO_OPENAPI_SERVICE_ERROR` / `returnReasonCode: "12"`.
   공공데이터포털에서 신청한 것이 "국토교통부(TAGO)_**버스노선정보**"뿐이라,
   **정류소정보 서비스는 별도 활용신청이 필요**하기 때문으로 보입니다.
   (같은 키로 `getCtyCodeList`는 `resultCode: "00"` 정상 → 키 자체는 멀쩡합니다.)
2. **대체: 캐시된 노선의 정류장 좌표** — 1번이 실패하면 `routeCache`에 들어있는
   노선들(즐겨찾기·최근 검색)의 정류장 좌표 중 현재 위치에서 가장 가까운 것을
   하버사인으로 고릅니다. 이미 검증된 버스노선정보 API 데이터라 추가 신청이
   필요 없습니다. 대신 **캐시에 있는 노선 위의 정류장만 후보**이고, 2km보다 멀면
   (다른 도시 노선만 캐시된 경우 등) 캡션을 비웁니다.

정류소정보 서비스를 나중에 활용신청하면 1번이 자동으로 살아납니다. 신청 후
아래 URL을 브라우저에 붙여넣어(**인코딩된** 서비스키) `resultCode: "00"`이 오는지
먼저 확인하세요:

```
https://apis.data.go.kr/1613000/BusSttnInfoInqireService/getCrdntPrxmtStaionList?serviceKey=<발급받은 키>&_type=json&gpsLati=37.498&gpsLong=127.028&numOfRows=5&pageNo=1
```

(좌표는 강남역 근처 예시입니다.) 응답 필드명이 다르면
`TagoNearbyStation.fromJson`(`lib/models/tago.dart`)의 후보 키 목록만 고치면 됩니다.

### 응답 인코딩 — 반드시 `bodyBytes`를 UTF-8로 직접 디코딩
TAGO는 Content-Type에 charset을 제대로 안 실어줍니다. 그런데 `http` 패키지의
`Response.body`는 charset이 없으면 **latin1**로 디코딩하기 때문에, 그대로 쓰면
정류장 이름·도시명 한글이 전부 깨집니다(`"?몄쥌?밸퀧"` 같은 문자).
그래서 모든 TAGO 응답은 `decodeTagoBody()`(`tago_bus_service.dart`)를 거쳐
`utf8.decode(res.bodyBytes)`로 읽습니다. 브라우저로 같은 URL을 열었을 때
한글이 깨져 보이는 것도 같은 원인이며, 그건 표시 문제일 뿐 데이터는 정상입니다.

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
   **`https://localhost`** 추가 — `KakaoJsConfig.sdkDomain`의 기본값과 같은 값이어야
   합니다 (다른 도메인을 쓰려면 `secrets/dart_defines.json`의 `KAKAO_JS_DOMAIN`과
   콘솔 등록값을 같이 바꾸면 됩니다). 아래 "왜 localhost인가" 참고.
3. **카카오맵 API 활성화**: 2026-07-21부터 이용 절차가 바뀌어서, 도메인 등록만으로는
   부족하고 앱 관리 페이지에서 카카오맵 API를 활성화해야 합니다. 무료 쿼터는
   **개발자 계정 기준 첫 번째로 활성화한 앱에만** 제공되므로, 다른 앱에서 이미
   카카오맵을 켠 적이 있다면 이 앱은 비즈월렛 연결(유료 API)이 필요할 수 있습니다.
4. `secrets/dart_defines.json`의 `KAKAO_JS_KEY` 채우기 (gitignored — 저장소엔 안 올라감)

**왜 `localhost`인가 (이전 문서의 `appassets.androidplatform.net`은 틀린 값이었습니다)**:
`webview_flutter`의 `loadFlutterAsset`은 내부적으로 `file:///android_asset/...`
(iOS도 `file://`)로 로드해서 페이지 오리진이 `file://`이 됩니다. 카카오 JS SDK는
등록된 도메인에서만 동작하는데 `file://`은 콘솔에 등록할 수 없습니다.
`appassets.androidplatform.net`은 `flutter_inappwebview`의 `WebViewAssetLoader`가
쓰는 가상 도메인이라 이 앱(`webview_flutter`)과는 무관합니다 — 등록해도 소용없습니다.
그래서 `KakaoMapView`는 asset을 문자열로 읽어
`loadHtmlString(html, baseUrl: KakaoJsConfig.sdkDomain)`으로 띄웁니다
(Android `loadDataWithBaseUrl` / iOS `loadHTMLString(_:baseURL:)`). 이러면 오리진이
`sdkDomain`이 되어 콘솔 등록값과 일치하고, Android/iOS 모두 같은 방식이 통합니다.

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
