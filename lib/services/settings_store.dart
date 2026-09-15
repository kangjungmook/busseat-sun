import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../theme/tokens.dart';

/// 앱 설정 로컬 저장.
///
/// 예전에는 테마·모드·스위치가 전부 [AppState]의 메모리 변수라서, **다크모드로
/// 고정해도 앱을 껐다 켜면 시스템 설정으로 돌아갔습니다.** 저장되는 건
/// 즐겨찾기와 노선 캐시뿐이었습니다.
///
/// 계정이 아니라 기기에 저장합니다 — 이 앱은 서버가 없습니다.
class AppSettings {
  final AppThemePref themePref;

  /// 계절에 따라 그늘/햇살 모드를 자동으로 고를지.
  final bool seasonAuto;

  /// 사용자가 직접 고른 모드. [seasonAuto]가 false일 때만 의미가 있습니다.
  final SunMode? modeOverride;

  /// 앱을 켤 때 '오늘' 화면 대신 번호 입력 화면으로 시작할지.
  final bool startOnKeypad;

  /// 결과 화면에 태양 고도·방위 값을 함께 보여줄지.
  final bool showCalcDetail;

  const AppSettings({
    this.themePref = AppThemePref.system,
    this.seasonAuto = true,
    this.modeOverride,
    this.startOnKeypad = false,
    this.showCalcDetail = false,
  });
}

class SettingsStore {
  static const _key = 'sunseat_settings_v1';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const AppSettings();

    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings(
        themePref: _enumByName(AppThemePref.values, m['themePref']) ?? AppThemePref.system,
        seasonAuto: m['seasonAuto'] as bool? ?? true,
        modeOverride: _enumByName(SunMode.values, m['modeOverride']),
        startOnKeypad: m['startOnKeypad'] as bool? ?? false,
        showCalcDetail: m['showCalcDetail'] as bool? ?? false,
      );
    } catch (_) {
      // 저장 형식이 바뀌었거나 값이 깨졌으면 기본값으로 시작한다.
      // 설정 하나 때문에 앱이 안 뜨는 것보다 낫다.
      return const AppSettings();
    }
  }

  static Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'themePref': s.themePref.name,
        'seasonAuto': s.seasonAuto,
        'modeOverride': s.modeOverride?.name,
        'startOnKeypad': s.startOnKeypad,
        'showCalcDetail': s.showCalcDetail,
      }),
    );
  }

  /// 이름으로 enum 찾기. 모르는 이름(예전 버전이 쓰던 값)이면 null.
  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
