import 'package:flutter/material.dart';

import '../logic/sun_calc.dart';
import '../models/route.dart';
import '../models/user.dart';
import '../services/favorites_store.dart';
import '../services/kakao_auth_service.dart';
import '../services/location_service.dart';
import '../theme/tokens.dart';

enum AppScreen {
  login,
  today,
  home,
  loading,
  night,
  result,
  seatMap,
  stopPicker,
  ar,
  map,
  settings,
  widget,
  tagoDebug,
}

const List<String> kNumKeys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'ABC', '0', '⌫'];
const List<String> kAbcKeys = ['M', 'N', 'A', 'B', 'C', 'D', 'E', 'G', '-', '123', '', ''];

class AppState extends ChangeNotifier {
  AppScreen screen = AppScreen.login;

  // 검색 / 키패드
  String query = '';
  String keypadMode = 'num'; // 'num' | 'abc'

  // 선택된 노선
  String? routeNo;
  int dirIndex = 0;

  // 시각 (분 단위, 0~1439)
  late int minutes;

  // 모드 / 테마
  SunMode? modeOverride;
  bool seasonAuto = true;
  AppThemePref themePref = AppThemePref.system;

  // 계정
  AppUser? user;
  bool get isLoggedIn => user != null;
  bool guestMode = false;

  // 즐겨찾기
  List<Favorite> favorites = [];
  bool favSheetOpen = false;
  String favLabel = '퇴근';

  // 동작 스위치: [정류장 도착 알림, 앱 켤 때 키패드 자동 열기, 계산 근거 자세히]
  List<bool> switches = [true, true, false];

  // 방면 선택 바텀시트
  bool dirPickerOpen = false;

  // 구간 지정
  int boardIndex = 0;
  int? alightIndex;
  String pickMode = 'board'; // 'board' | 'alight'

  // 지도 안내
  bool guiding = false;

  // AR
  double? arHeadingOverride; // null이면 실제 나침반 센서 값을 쓴다

  // 위치
  LocationResult? location;
  bool locationLoading = false;

  // 결과 화면 진입 애니메이션 트리거
  bool resultEntered = false;

  AppState() {
    final now = DateTime.now();
    minutes = (now.hour * 60 + now.minute).clamp(0, 1439);
    KakaoAuthService.init();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    favorites = await FavoritesStore.load();
    notifyListeners();
  }

  // ---- 파생 값 ----

  SunMode get seasonalDefault {
    final m = DateTime.now().month;
    return (m >= 4 && m <= 10) ? SunMode.shade : SunMode.sun;
  }

  SunMode get effectiveMode => modeOverride ?? (seasonAuto ? seasonalDefault : SunMode.shade);

  bool get isNight => SunCalc.isNight(minutes);

  BusRoute? get currentRoute => routeNo == null ? null : findRoute(routeNo!);

  RouteDir? get currentDir {
    final r = currentRoute;
    if (r == null) return null;
    return r.dirs[dirIndex.clamp(0, r.dirs.length - 1)];
  }

  List<BusRoute> get matches {
    if (query.isEmpty) return const [];
    return kSeedRoutes.where((r) => r.no.startsWith(query)).toList();
  }

  List<String> get keypadKeys => keypadMode == 'abc' ? kAbcKeys : kNumKeys;

  String get ctaText => matches.isNotEmpty ? '${matches.first.no}번 ${effectiveMode == SunMode.shade ? '그늘' : '햇살'} 계산하기' : '버스 번호를 입력하세요';

  String get todayGreeting {
    final hh = DateTime.now().hour;
    final lead = hh < 11 ? '출근길이네요.' : (hh < 20 ? '퇴근길이네요.' : '늦은 귀갓길이네요.');
    return '$lead 오늘은 이렇게 앉으세요';
  }

  String get clockLabel {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // ---- 네비게이션 ----

  void goto(AppScreen s) {
    screen = s;
    notifyListeners();
  }

  void goHome() {
    screen = AppScreen.home;
    query = '';
    notifyListeners();
  }

  // ---- 로그인 ----

  Future<String?> loginWithKakao() async {
    try {
      final u = await KakaoAuthService.login();
      user = u;
      guestMode = false;
      _enterAfterLogin();
      return null;
    } on KakaoNotConfiguredException catch (e) {
      return e.toString();
    } catch (e) {
      return '카카오 로그인에 실패했어요. 다시 시도해 주세요.';
    }
  }

  void loginAsGuest() {
    guestMode = true;
    user = null;
    _enterAfterLogin();
  }

  void _enterAfterLogin() {
    screen = favorites.isNotEmpty ? AppScreen.today : AppScreen.home;
    notifyListeners();
  }

  Future<void> logout() async {
    await KakaoAuthService.logout();
    user = null;
    guestMode = false;
    screen = AppScreen.login;
    notifyListeners();
  }

  // ---- 검색 / 키패드 ----

  void tapKey(String key) {
    if (key.isEmpty) return;
    if (key == 'ABC') {
      keypadMode = 'abc';
    } else if (key == '123') {
      keypadMode = 'num';
    } else if (key == '⌫') {
      if (query.isNotEmpty) query = query.substring(0, query.length - 1);
    } else {
      if (query.length < 6) query += key;
    }
    notifyListeners();
  }

  void clearQuery() {
    query = '';
    notifyListeners();
  }

  void submitSearch() {
    if (matches.isNotEmpty) chooseRoute(matches.first);
  }

  void chooseRoute(BusRoute route) {
    if (route.dirs.length > 1) {
      routeNo = route.no;
      dirPickerOpen = true;
      notifyListeners();
    } else {
      pickDir(route, 0);
    }
  }

  void closeDirPicker() {
    dirPickerOpen = false;
    screen = AppScreen.home;
    notifyListeners();
  }

  Future<void> pickDir(BusRoute route, int i) async {
    routeNo = route.no;
    dirIndex = i;
    dirPickerOpen = false;
    screen = AppScreen.loading;
    boardIndex = 0;
    alightIndex = null;
    resultEntered = false;
    notifyListeners();

    final night = isNight;
    await Future.delayed(const Duration(milliseconds: 850));
    screen = night ? AppScreen.night : AppScreen.result;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 60));
    resultEntered = true;
    notifyListeners();
  }

  void useDaytime() {
    minutes = 972;
    resultEntered = false;
    screen = AppScreen.result;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 60), () {
      resultEntered = true;
      notifyListeners();
    });
  }

  // ---- 모드 / 테마 ----

  void setMode(SunMode mode) {
    modeOverride = mode;
    seasonAuto = false;
    notifyListeners();
  }

  void setSeasonAuto() {
    seasonAuto = true;
    modeOverride = null;
    notifyListeners();
  }

  void toggleMode() {
    setMode(effectiveMode == SunMode.shade ? SunMode.sun : SunMode.shade);
  }

  void setThemePref(AppThemePref pref) {
    themePref = pref;
    notifyListeners();
  }

  void toggleSwitch(int i) {
    switches[i] = !switches[i];
    notifyListeners();
  }

  // ---- 구간 지정 ----

  void pickBoardTab() {
    pickMode = 'board';
    notifyListeners();
  }

  void pickAlightTab() {
    pickMode = 'alight';
    notifyListeners();
  }

  void tapStop(int i, int last) {
    if (pickMode == 'board') {
      final a = alightIndex;
      boardIndex = i > last - 1 ? last - 1 : i;
      alightIndex = (a != null && a <= i) ? null : a;
      pickMode = 'alight';
    } else {
      alightIndex = i > boardIndex ? i : boardIndex + 1;
    }
    notifyListeners();
  }

  void wholeLine() {
    boardIndex = 0;
    alightIndex = null;
    pickMode = 'board';
    screen = AppScreen.result;
    notifyListeners();
  }

  void applyStops() {
    screen = AppScreen.result;
    notifyListeners();
  }

  Future<void> useNearestStop() async {
    // 실제 서비스에서는 TOPIS API로 좌표 기반 최근접 정류장을 조회한다.
    final dir = currentDir;
    if (dir == null) return;
    final nearIdx = 1.clamp(0, dir.stops.length - 1);
    if (pickMode == 'board') {
      boardIndex = nearIdx;
    } else {
      alightIndex = nearIdx > boardIndex ? nearIdx : boardIndex + 1;
    }
    notifyListeners();
  }

  // ---- 즐겨찾기 ----

  void openFavSheet() {
    favSheetOpen = true;
    notifyListeners();
  }

  void closeFavSheet() {
    favSheetOpen = false;
    notifyListeners();
  }

  void setFavLabel(String label) {
    favLabel = label;
    notifyListeners();
  }

  bool get isCurrentFavorite {
    final r = currentRoute;
    if (r == null) return false;
    return favorites.any((f) => f.routeNo == r.no && f.dirIndex == dirIndex);
  }

  Future<void> saveFavorite() async {
    final route = currentRoute;
    final dir = currentDir;
    if (route == null || dir == null) return;
    final last = dir.stops.length - 1;
    final bIdx = boardIndex.clamp(0, last - 1 < 0 ? 0 : last - 1);
    final aIdx = alightIndex ?? last;
    favorites = [
      ...favorites.where((f) => !(f.routeNo == route.no && f.dirIndex == dirIndex)),
      Favorite(
        routeNo: route.no,
        dirIndex: dirIndex,
        label: favLabel,
        from: dir.stops[bIdx],
        to: dir.stops[aIdx],
        boardIndex: bIdx,
        alightIndex: aIdx,
      ),
    ];
    await FavoritesStore.save(favorites);
    favSheetOpen = false;
    notifyListeners();
  }

  void openFavoriteResult(Favorite fav) {
    routeNo = fav.routeNo;
    dirIndex = fav.dirIndex;
    boardIndex = fav.boardIndex;
    alightIndex = fav.alightIndex;
    resultEntered = false;
    screen = AppScreen.result;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 60), () {
      resultEntered = true;
      notifyListeners();
    });
  }

  // ---- 시각 슬라이더 (지도 / AR) ----

  void setMinutes(int m) {
    minutes = m.clamp(300, 1200);
    notifyListeners();
  }

  void resetToNow() {
    final now = DateTime.now();
    minutes = (now.hour * 60 + now.minute).clamp(0, 1439);
    notifyListeners();
  }

  // ---- 지도 안내 ----

  void startGuide() {
    guiding = true;
    notifyListeners();
  }

  void stopGuide() {
    guiding = false;
    notifyListeners();
  }

  // ---- AR ----

  void setArHeadingOverride(double? heading) {
    arHeadingOverride = heading;
    notifyListeners();
  }

  // ---- 위치 ----

  Future<void> refreshLocation() async {
    locationLoading = true;
    notifyListeners();
    try {
      location = await LocationService.current();
    } finally {
      locationLoading = false;
      notifyListeners();
    }
  }
}
