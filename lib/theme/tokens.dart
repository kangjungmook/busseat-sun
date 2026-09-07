import 'package:flutter/material.dart';

/// 그늘 / 햇살 모드 — primary 색이 통째로 바뀐다.
enum SunMode { shade, sun }

/// 라이트 / 다크 / 시스템 테마.
enum AppThemePref { system, light, dark }

class ModeTokens {
  final Color primary;
  final Color accent;
  final Color onPrimary;
  final Color primaryTextLight;
  final Color primaryTextDark;

  const ModeTokens({
    required this.primary,
    required this.accent,
    required this.onPrimary,
    required this.primaryTextLight,
    required this.primaryTextDark,
  });
}

const Map<SunMode, ModeTokens> kModeTokens = {
  SunMode.shade: ModeTokens(
    primary: Color(0xFF4F46E5),
    accent: Color(0xFF7C3AED),
    onPrimary: Color(0xFFFFFFFF),
    primaryTextLight: Color(0xFF4338CA),
    primaryTextDark: Color(0xFFA5B4FC),
  ),
  SunMode.sun: ModeTokens(
    primary: Color(0xFFF59E0B),
    accent: Color(0xFFFB923C),
    onPrimary: Color(0xFF1C1917),
    primaryTextLight: Color(0xFFB45309),
    primaryTextDark: Color(0xFFFCD34D),
  ),
};

class SurfaceTokens {
  final Color background;
  final Color surface;
  final Color text;
  final Color textMuted;
  final Color subtle;
  final Color line;
  final Color mapBase;
  final Color mapRoad;
  final Color mapBlock;
  final Color grey; // 지하·터널 해치

  const SurfaceTokens({
    required this.background,
    required this.surface,
    required this.text,
    required this.textMuted,
    required this.subtle,
    required this.line,
    required this.mapBase,
    required this.mapRoad,
    required this.mapBlock,
    required this.grey,
  });
}

const SurfaceTokens kLightSurface = SurfaceTokens(
  background: Color(0xFFFAFAF9),
  surface: Color(0xFFFFFFFF),
  text: Color(0xFF1C1917),
  textMuted: Color(0xFF78716C),
  subtle: Color(0xFFF2F1EF),
  line: Color(0x1A1C1917),
  mapBase: Color(0xFFEDEAE4),
  mapRoad: Color(0xFFFBFAF8),
  mapBlock: Color(0xFFE2DED7),
  grey: Color(0xFFC7C2BA),
);

const SurfaceTokens kDarkSurface = SurfaceTokens(
  background: Color(0xFF0C0A09),
  surface: Color(0xFF1C1917),
  text: Color(0xFFFAFAF9),
  textMuted: Color(0xFFA8A29E),
  subtle: Color(0xFF262322),
  line: Color(0x24FAFAF9),
  mapBase: Color(0xFF131110),
  mapRoad: Color(0xFF211E1C),
  mapBlock: Color(0xFF1A1716),
  grey: Color(0xFF57534E),
);

// 의미 색 (모드/테마 무관 고정)
const Color kLocationBlue = Color(0xFF2563EB);
const Color kKakaoYellow = Color(0xFFFEE500);
const Color kKakaoInk = Color(0xFF191600);
const Color kBadgeExpress = Color(0xFFDC2626); // 직행좌석 / 광역
const Color kBadgeTrunk = Color(0xFF2563EB); // 간선

/// 앱의 통합 팔레트: 표면 + 모드 색을 한번에 들고 다니는 헬퍼.
class AppPalette {
  final Brightness brightness;
  final SunMode mode;
  final SurfaceTokens surface;
  final ModeTokens modeTokens;

  AppPalette({required this.brightness, required this.mode})
      : surface = brightness == Brightness.dark ? kDarkSurface : kLightSurface,
        modeTokens = kModeTokens[mode]!;

  bool get isDark => brightness == Brightness.dark;

  Color get background => surface.background;
  Color get surfaceColor => surface.surface;
  Color get text => surface.text;
  Color get textMuted => surface.textMuted;
  Color get subtle => surface.subtle;
  Color get line => surface.line;

  Color get primary => modeTokens.primary;
  Color get accent => modeTokens.accent;
  Color get onPrimary => modeTokens.onPrimary;

  /// 강조 텍스트 — 원색 위에 직접 쓰지 말 것. 배경 위 강조용.
  Color get primaryText => isDark ? modeTokens.primaryTextDark : modeTokens.primaryTextLight;

  /// 반대 개념 색 (좌석 지도 "나쁜 쪽" 배경 등에 사용).
  Color get badColor => mode == SunMode.shade ? const Color(0xFFFB923C) : const Color(0xFF4F46E5);

  Color get badForeground => mode == SunMode.shade ? const Color(0xFF1C1917) : const Color(0xFFFFFFFF);

  Color get sunDiscColor => mode == SunMode.sun ? modeTokens.accent : const Color(0xFFFB923C);

  BoxShadow get cardShadow => isDark ? const BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8)) : BoxShadow(color: const Color(0xFF1C1917).withOpacity(.10), blurRadius: 24, offset: const Offset(0, 8));
}

/// spacing 스케일: 4 · 6 · 8 · 11 · 14 · 18 · 22
class AppSpacing {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double base = 11;
  static const double lg = 14;
  static const double xl = 18;
  static const double xxl = 22;

  static const double screenPad = 16; // 16~18
  static const double screenPadLg = 18;
}

class AppRadius {
  static const double card = 24; // 20~26
  static const double cardLg = 26;
  static const double button = 17; // 16~18
  static const double pill = 999;
  static const double seat = 10;
}

const double kMinTouchTarget = 48;
const double kCtaHeight = 56;

class AppTextStyles {
  static const String family = 'Pretendard';

  static TextStyle headline(Color color) => TextStyle(
        fontFamily: family,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
        height: 1.16,
        color: color,
      );

  static TextStyle bigPercent(Color color) => TextStyle(
        fontFamily: family,
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.8,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle numberInput(Color color) => TextStyle(
        fontFamily: family,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle sectionTitle(Color color, {double size = 21}) => TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: color,
      );

  static TextStyle body(Color color) => TextStyle(
        fontFamily: family,
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle caption(Color color) => TextStyle(
        fontFamily: family,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle microLabel(Color color) => TextStyle(
        fontFamily: family,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: color,
      );

  static TextStyle tabular(Color color, {double size = 14, FontWeight weight = FontWeight.w700}) => TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

ThemeData buildAppTheme(AppPalette p) {
  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    fontFamily: AppTextStyles.family,
    scaffoldBackgroundColor: p.background,
    colorScheme: ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.accent,
      onSecondary: p.onPrimary,
      error: const Color(0xFFDC2626),
      onError: Colors.white,
      surface: p.surfaceColor,
      onSurface: p.text,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
