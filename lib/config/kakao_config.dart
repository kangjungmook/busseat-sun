/// 카카오 로그인 설정.
///
/// 네이티브 앱 키가 없으면 로그인 기능은 동작하지 않고 게스트 모드로만 쓸 수 있다.
///
/// 키는 소스에 직접 넣지 않고 빌드 시 `--dart-define`으로 주입한다.
/// `secrets/dart_defines.json` (gitignored, `secrets/dart_defines.example.json` 참고)에
/// 실제 값을 넣고 아래처럼 실행한다:
///
/// ```sh
/// flutter run --dart-define-from-file=secrets/dart_defines.json
/// ```
///
/// 네이티브 쪽 스킴은 각각 gitignored 파일에서 자동으로 채워진다:
/// - Android: android/app/secrets.properties → AndroidManifest 리다이렉트 액티비티
/// - iOS: ios/Flutter/Secrets.xcconfig → Info.plist CFBundleURLSchemes
class KakaoConfig {
  static const String nativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => nativeAppKey.isNotEmpty;
}
