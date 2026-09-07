/// 카카오맵 JavaScript SDK 키 (네이티브 앱 키와 다른 키다).
///
/// 카카오 디벨로퍼스 → 앱 → **`플랫폼 키`** → **`JavaScript 키`** 섹션에서 키를
/// 확인하고, 같은 카드의 **`JavaScript SDK 도메인`**에
/// `https://appassets.androidplatform.net`을 등록해야 [KakaoMapView]가 로드하는
/// 지도가 뜬다 (Android WebView가 앱 내 asset을 서빙할 때 쓰는 가상 도메인).
/// 콘솔 개편 전 경로였던 `플랫폼 → Web → 사이트 도메인`은 더 이상 없다.
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
