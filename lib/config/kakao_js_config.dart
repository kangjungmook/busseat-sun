/// 카카오맵 JavaScript SDK 키 (네이티브 앱 키와 다른 키다).
///
/// 카카오 디벨로퍼스 → 앱 → **`플랫폼 키`** → **`JavaScript 키`** 에서 키를
/// 확인하고, 같은 카드의 **`JavaScript SDK 도메인`**에 [sdkDomain]과 **똑같은**
/// 값을 등록해야 [KakaoMapView]가 로드하는 지도가 뜬다.
/// (콘솔 개편 전 경로였던 `플랫폼 → Web → 사이트 도메인`은 더 이상 없다.)
///
/// 키는 다른 설정과 동일하게 `secrets/dart_defines.json`(gitignored)의
/// KAKAO_JS_KEY로 주입한다.
class KakaoJsConfig {
  static const String jsKey = String.fromEnvironment(
    'KAKAO_JS_KEY',
    defaultValue: '',
  );

  /// 지도 HTML을 띄울 때 WebView에 씌울 오리진.
  ///
  /// 이 값이 필요한 이유: `webview_flutter`의 `loadFlutterAsset`은 실제로
  /// `file:///android_asset/...`(iOS도 file://)로 로드해서 오리진이 `file://`이
  /// 된다. 카카오 JS SDK는 등록된 도메인에서만 동작하는데 `file://`은 콘솔에
  /// 등록할 수 없다 — 그래서 [KakaoMapView]는 asset을 문자열로 읽어
  /// `loadHtmlString(html, baseUrl: sdkDomain)`으로 띄운다 (Android
  /// `loadDataWithBaseUrl` / iOS `loadHTMLString(_:baseURL:)`). 그러면 페이지
  /// 오리진이 이 값이 되고, 콘솔에 등록한 도메인과 일치하게 된다.
  ///
  /// 실제 소유한 도메인이 있으면 그걸 쓰고 콘솔에도 같은 값을 등록하면 된다.
  /// 없으면 기본값(`https://localhost`)을 그대로 콘솔에 등록하면 된다.
  /// (`secrets/dart_defines.json`의 KAKAO_JS_DOMAIN으로 덮어쓸 수 있다.)
  ///
  /// ⚠️ 예전에 이 자리에 적어뒀던 `https://appassets.androidplatform.net`은
  /// 틀린 값이었다 — 그건 `flutter_inappwebview`의 `WebViewAssetLoader`가 쓰는
  /// 가상 도메인이라 `webview_flutter`를 쓰는 이 앱과는 무관하다.
  static const String sdkDomain = String.fromEnvironment(
    'KAKAO_JS_DOMAIN',
    defaultValue: 'https://localhost',
  );

  static bool get isConfigured => jsKey.isNotEmpty;
}
