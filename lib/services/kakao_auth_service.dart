import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../config/kakao_config.dart';
import '../models/user.dart';

/// 카카오 단일 소셜 로그인 래퍼. 네이티브 앱 키가 설정되지 않으면
/// [KakaoNotConfiguredException]을 던진다 — 호출부는 게스트 모드로 안내한다.
class KakaoAuthService {
  static void init() {
    if (!KakaoConfig.isConfigured) return;
    KakaoSdk.init(nativeAppKey: KakaoConfig.nativeAppKey);
  }

  static Future<AppUser> login() async {
    if (!KakaoConfig.isConfigured) {
      throw KakaoNotConfiguredException();
    }
    final installed = await isKakaoTalkInstalled();
    try {
      if (installed) {
        await UserApi.instance.loginWithKakaoTalk();
      } else {
        await UserApi.instance.loginWithKakaoAccount();
      }
    } catch (_) {
      await UserApi.instance.loginWithKakaoAccount();
    }
    final me = await UserApi.instance.me();
    return AppUser(
      id: me.id.toString(),
      nickname: me.kakaoAccount?.profile?.nickname ?? '카카오 계정',
    );
  }

  static Future<void> logout() async {
    if (!KakaoConfig.isConfigured) return;
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // 이미 로그아웃 상태거나 토큰이 없는 경우 무시.
    }
  }
}

class KakaoNotConfiguredException implements Exception {
  @override
  String toString() => '카카오 네이티브 앱 키가 설정되지 않았습니다. lib/config/kakao_config.dart 참고.';
}
