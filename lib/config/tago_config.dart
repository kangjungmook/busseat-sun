/// 국토교통부 TAGO(국가대중교통정보센터) 버스노선정보 API 설정.
///
/// 키는 소스에 직접 넣지 않는다 — [KakaoConfig]와 동일하게
/// `secrets/dart_defines.json` (gitignored)의 TAGO_API_KEY를 dart-define으로 주입한다.
///
/// ```sh
/// flutter run --dart-define-from-file=secrets/dart_defines.json
/// ```
class TagoConfig {
  static const String apiKey = String.fromEnvironment(
    'TAGO_API_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => apiKey.isNotEmpty;
}
