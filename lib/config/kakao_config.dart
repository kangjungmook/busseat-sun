/// 카카오 로그인 설정.
///
/// 네이티브 앱 키가 없으면 로그인 기능은 동작하지 않고 게스트 모드로만 쓸 수 있다.
/// 키를 받으면:
/// 1. 아래 [nativeAppKey] 기본값을 채우거나, 빌드 시
///    `--dart-define=KAKAO_NATIVE_APP_KEY=xxxxx` 로 주입한다.
/// 2. android/app/src/main/AndroidManifest.xml 의 <application> 안에
///    카카오 로그인 리다이렉트용 액티비티(스킴 kakao{NATIVE_APP_KEY}://oauth)를 등록한다.
/// 3. ios/Runner/Info.plist 에 CFBundleURLSchemes(kakao{NATIVE_APP_KEY})와
///    LSApplicationQueriesSchemes(kakaokompassauth, kakaolink 등)를 추가한다.
class KakaoConfig {
  static const String nativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => nativeAppKey.isNotEmpty;
}
