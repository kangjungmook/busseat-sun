import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunseat/services/settings_store.dart';
import 'package:sunseat/theme/tokens.dart';

/// 설정 저장 검증.
///
/// 예전에는 테마·모드·스위치가 메모리에만 있어서 **앱을 껐다 켜면 전부
/// 초기화**됐다. 다크모드로 고정해도 다음 실행에 시스템 설정으로 돌아갔다.
/// 여기서 보는 건 두 가지다: 넣은 값이 그대로 돌아오는가, 그리고 저장된 값이
/// 깨졌을 때 앱이 죽지 않고 기본값으로 시작하는가.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('저장한 설정이 그대로 돌아온다', () async {
    await SettingsStore.save(const AppSettings(
      themePref: AppThemePref.dark,
      seasonAuto: false,
      modeOverride: SunMode.sun,
      startOnKeypad: true,
      showCalcDetail: true,
    ));

    final s = await SettingsStore.load();
    expect(s.themePref, AppThemePref.dark);
    expect(s.seasonAuto, isFalse);
    expect(s.modeOverride, SunMode.sun);
    expect(s.startOnKeypad, isTrue);
    expect(s.showCalcDetail, isTrue);
  });

  test('한 번도 저장한 적 없으면 기본값', () async {
    final s = await SettingsStore.load();
    expect(s.themePref, AppThemePref.system);
    expect(s.seasonAuto, isTrue);
    expect(s.modeOverride, isNull);
    expect(s.startOnKeypad, isFalse);
    expect(s.showCalcDetail, isFalse);
  });

  test('modeOverride는 null로도 저장된다 (계절 자동으로 되돌리기)', () async {
    await SettingsStore.save(const AppSettings(modeOverride: SunMode.shade));
    await SettingsStore.save(const AppSettings());
    expect((await SettingsStore.load()).modeOverride, isNull);
  });

  test('저장된 값이 깨져 있어도 기본값으로 시작한다 — 설정 하나로 앱이 죽으면 안 된다', () async {
    SharedPreferences.setMockInitialValues({'sunseat_settings_v1': '{이건 JSON이 아니다'});
    expect((await SettingsStore.load()).themePref, AppThemePref.system);
  });

  test('모르는 enum 이름은 무시하고 기본값 — 예전 버전이 쓰던 값이 남아 있을 수 있다', () async {
    SharedPreferences.setMockInitialValues({
      'sunseat_settings_v1': '{"themePref":"sepia","modeOverride":"rain","seasonAuto":false}',
    });
    final s = await SettingsStore.load();
    expect(s.themePref, AppThemePref.system);
    expect(s.modeOverride, isNull);
    expect(s.seasonAuto, isFalse, reason: '알아볼 수 있는 값은 그대로 살린다');
  });
}
