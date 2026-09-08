/// 카카오 로컬 API(REST) 키 — 좌표를 행정구역으로 바꿀 때 쓴다.
///
/// 네이티브 앱 키·JavaScript 키와 **또 다른** 키다. 카카오 디벨로퍼스 →
/// 앱 → `플랫폼 키` → `REST API 키`에서 확인한다.
///
/// 왜 필요한가: TAGO 노선 검색은 `cityCode`가 필수라, 도시를 모르면 도시
/// 목록(150~250개)을 전부 훑어야 한다 = 검색 1회에 API 200번. 공개 배포에는
/// 감당이 안 되는 양이라(개발계정 일일 한도가 보통 1,000건), 현재 위치를
/// 행정구역으로 바꿔 도시를 먼저 좁힌다 — 200회가 1~2회가 된다.
///
/// 키는 `secrets/dart_defines.json`(gitignored)의 KAKAO_REST_API_KEY로 주입한다.
class KakaoLocalConfig {
  static const String restApiKey = String.fromEnvironment(
    'KAKAO_REST_API_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => restApiKey.isNotEmpty;
}
