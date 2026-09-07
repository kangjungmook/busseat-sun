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

### 지도 SDK — 아직 미구현, 방식 결정 필요
`map` 화면은 지금 도로 그리드 + 건물 블록을 직접 그린 플레이스홀더입니다.
카카오맵 **네이티브 Android/iOS SDK**로 교체하려면 Flutter에서 두 가지 방법이 있습니다.

1. **PlatformView + 네이티브 브릿지** — 진짜 네이티브 SDK를 Kotlin/Swift로 직접 붙이고
   Flutter `PlatformView`로 감싼다. 가장 정확하지만 네이티브 코드 작업이 크고,
   릴리스에 쓸 실제 서명 키스토어의 키 해시를 카카오 디벨로퍼스에 등록해야 한다
   (그 키 해시는 개발자 본인 컴퓨터에서 `keytool`로 뽑아야 함 — 이 저장소만으론 대신할 수 없음).
2. **WebView + 카카오맵 JavaScript SDK** — `webview_flutter`로 카카오맵 JS SDK를 담은
   HTML을 로드. 네이티브 코드가 거의 필요 없어 빠르지만, 네이티브 앱 키가 아니라
   별도의 **JavaScript 키**와 "웹 플랫폼 도메인" 등록이 카카오 디벨로퍼스에서 필요하다.

### 노선/정류장 데이터 — 키는 받았지만 아직 연결 안 함
`lib/models/route.dart`의 6개 노선은 시드 데이터 그대로입니다.
TAGO 버스노선정보 API 키는 `lib/config/tago_config.dart`에 연결해뒀고,
`lib/services/tago_bus_service.dart`에 뼈대만 만들어뒀습니다.

⚠️ **주의**: 이 세션은 data.go.kr의 실제 API 명세 문서를 인터넷에서 조회할 수 없어서
(`www.data.go.kr` 접근이 차단됨), `tago_bus_service.dart` 안의 엔드포인트 경로·파라미터명은
**검증되지 않았습니다** — 공공데이터포털 버스 API들의 일반적인 패턴만 반영한 추정치입니다.
실제로 쓰려면 활용신청 상세 페이지의 "OpenAPI 개발가이드" 문서를 보고 맞춰야 합니다.

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
