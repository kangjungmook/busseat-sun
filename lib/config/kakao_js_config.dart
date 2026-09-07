/// 카카오맵 JavaScript SDK 키 (네이티브 앱 키와 다른 키다).
///
/// 카카오 디벨로퍼스 → 내 애플리케이션 → 앱 키 → **JavaScript 키**를 발급받고,
/// 플랫폼 → Web에 사이트 도메인으로 `https://appassets.androidplatform.net`을
/// 등록해야 [KakaoMapView]가 로드하는 지도가 뜬다 (Android WebView가 앱 내
/// asset을 서빙할 때 쓰는 가상 도메인).
///
/// 키는 다른 설정과 동일하게 `secrets/dart_defines.json`(gitignored)의
/// KAKAO_JS_KEY로 주입한다.
class KakaoJsConfig {
  static const String jsKey = String.fromEnvironment(
    'KAKAO_JS_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => jsKey.isNotEmpty;
}
