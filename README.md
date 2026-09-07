# 햇살좌석 (SunSeat)

버스 탑승 직전 3초 안에 "어느 쪽 창가에 앉아야 그늘/볕이 좋은지"만 알려주는 단일 목적 앱.

Claude Design 핸드오프(`FLUTTER_HANDOFF.md`, `햇살좌석 앱.dc.html`)를 기반으로 구현한 Flutter 앱입니다.

## 실행

```bash
flutter pub get
flutter run
```

## 아직 채워야 하는 것

### 카카오 로그인
`kakao_flutter_sdk_user`를 붙여뒀지만 네이티브 앱 키가 없으면 동작하지 않고
"카카오 네이티브 앱 키가 설정되지 않았습니다" 안내와 함께 게스트 모드로만 쓸 수 있습니다.

키를 받으면:
1. `flutter run --dart-define=KAKAO_NATIVE_APP_KEY=xxxxx` 로 실행하거나
   `lib/config/kakao_config.dart`의 기본값을 채운다.
2. `android/gradle.properties`에 `KAKAO_NATIVE_APP_KEY=xxxxx` 추가
   (AndroidManifest의 리다이렉트 스킴이 자동으로 채워짐).
3. `ios/Runner/Info.plist`의 `CFBundleURLSchemes` 값 `kakaoNATIVE_APP_KEY`를
   `kakao{실제 키}`로 교체.

### 지도 SDK
`map` 화면은 지금 도로 그리드 + 건물 블록을 직접 그린 플레이스홀더입니다.
카카오맵/네이버맵 SDK 키를 받으면 `lib/widgets/route_map_painter.dart` 자리를
실제 지도 위젯으로 교체합니다.

### 노선/정류장 데이터
`lib/models/route.dart`의 6개 노선은 시드 데이터입니다. 서울 TOPIS API 연동 시
`FavoritesStore`/`AppState`의 노선 조회 부분을 API 호출로 교체합니다.

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
