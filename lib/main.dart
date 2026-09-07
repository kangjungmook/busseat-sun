import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/ar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/night_screen.dart';
import 'screens/result_screen.dart';
import 'screens/seat_map_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stop_picker_screen.dart';
import 'screens/today_screen.dart';
import 'screens/widget_screen.dart';
import 'state/app_state.dart';
import 'theme/tokens.dart';
import 'widgets/dir_picker_sheet.dart';
import 'widgets/fav_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const SunSeatApp(),
    ),
  );
}

class SunSeatApp extends StatelessWidget {
  const SunSeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ThemedApp();
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final brightness = switch (state.themePref) {
      AppThemePref.light => Brightness.light,
      AppThemePref.dark => Brightness.dark,
      AppThemePref.system => platformBrightness,
    };
    final palette = AppPalette(brightness: brightness, mode: state.effectiveMode);

    return MaterialApp(
      title: '햇살좌석',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(palette),
      home: AnimatedTheme(
        data: buildAppTheme(palette),
        duration: const Duration(milliseconds: 250),
        curve: Curves.ease,
        child: AppRoot(palette: palette),
      ),
    );
  }
}

class AppRoot extends StatelessWidget {
  final AppPalette palette;

  const AppRoot({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    Widget body;
    switch (state.screen) {
      case AppScreen.login:
        body = LoginScreen(palette: palette);
        break;
      case AppScreen.today:
        body = TodayScreen(palette: palette);
        break;
      case AppScreen.home:
        body = HomeScreen(palette: palette);
        break;
      case AppScreen.loading:
        body = LoadingScreen(palette: palette);
        break;
      case AppScreen.night:
        body = NightScreen(palette: palette);
        break;
      case AppScreen.result:
        body = ResultScreen(palette: palette);
        break;
      case AppScreen.seatMap:
        body = SeatMapScreen(palette: palette);
        break;
      case AppScreen.stopPicker:
        body = StopPickerScreen(palette: palette);
        break;
      case AppScreen.ar:
        body = ArScreen(palette: palette);
        break;
      case AppScreen.map:
        body = MapScreen(palette: palette);
        break;
      case AppScreen.settings:
        body = SettingsScreen(palette: palette);
        break;
      case AppScreen.widget:
        body = WidgetScreen(palette: palette);
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: palette.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: DefaultTextStyle(
              style: TextStyle(fontFamily: AppTextStyles.family, color: palette.text),
              child: body,
            ),
          ),
          if (state.dirPickerOpen) DirPickerSheet(palette: palette),
          if (state.favSheetOpen) FavSheet(palette: palette),
        ],
      ),
    );
  }
}
