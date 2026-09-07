import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/geo.dart';
import '../logic/sun_calc.dart';
import '../models/route.dart';
import '../models/tago.dart';
import '../models/user.dart';
import '../services/favorites_store.dart';
import '../services/kakao_auth_service.dart';
import '../services/location_service.dart';
import '../services/route_cache.dart';
import '../services/tago_route_repository.dart';
import '../services/tago_station_service.dart';
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

  // 선택된 노선 — TAGO에서 실시간으로 조회해 완전히 조립된 것을 그대로 들고 있는다
  // (매번 노선번호로 다시 찾지 않는다).
  BusRoute? resolvedRoute;
  int dirIndex = 0;

  // TAGO 검색 결과 캐시 — 노선번호 → BusRoute. 세션 내 재검색을 막고,
  // '오늘' 화면이 즐겨찾기를 앱 실행 즉시 그릴 수 있게 한다.
  Map<String, BusRoute> routeCache = {};
  final Set<String> _resolving = {};
  bool searching = false;
  String? searchError;

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

  // 근접 정류장 (TAGO 좌표기반 정류소 조회 — 홈 화면 "가까운 정류장" 캡션용).
  // ⚠️ getCrdntPrxmtStaionList는 이 세션에서 실제 호출로 검증하지 못했다 —
  // 실패해도 조용히 무시하고 캡션은 안내 문구로 대체한다.
  TagoNearbyStation? nearestKnownStation;
  bool nearbyStationLoading = false;

  // 결과 화면 진입 애니메이션 트리거
  bool resultEntered = false;

  AppState() {
    final now = DateTime.now();
    minutes = (now.hour * 60 + now.minute).clamp(0, 1439);
    KakaoAuthService.init();
    _loadFavorites();
    _loadRouteCache();
  }

  Future<void> _loadFavorites() async {
    favorites = await FavoritesStore.load();
    notifyListeners();
  }

  Future<void> _loadRouteCache() async {
    routeCache = await RouteCache.allCached();
    notifyListeners();
    // 캐시에 없는 즐겨찾기는 '오늘' 화면이 뜨기 전에 백그라운드로 미리 채워둔다.
    for (final f in favorites) {
      ensureRouteCached(f.routeNo);
    }
  }

  Future<void> _cacheRoute(BusRoute route) async {
    routeCache[route.no] = route;
    await RouteCache.put(route);
  }

  /// 캐시에 없으면 조용히 백그라운드에서 채워온다 (실패해도 화면을 막지 않는다).
  Future<void> ensureRouteCached(String routeNo) async {
    if (routeCache.containsKey(routeNo) || _resolving.contains(routeNo)) return;
    _resolving.add(routeNo);
    try {
      final route = await TagoRouteRepository.search(routeNo);
      if (route != null) await _cacheRoute(route);
    } catch (_) {
      // '오늘' 화면은 다음에 다시 시도된다 — 여기서 에러를 표면화하지 않는다.
    } finally {
      _resolving.remove(routeNo);
      notifyListeners();
    }
  }

  // ---- 파생 값 ----

  SunMode get seasonalDefault {
    final m = DateTime.now().month;
    return (m >= 4 && m <= 10) ? SunMode.shade : SunMode.sun;
  }

  SunMode get effectiveMode => modeOverride ?? (seasonAuto ? seasonalDefault : SunMode.shade);

  bool get isNight => SunCalc.isNight(minutes);

  BusRoute? get currentRoute => resolvedRoute;

  RouteDir? get currentDir {
    final r = currentRoute;
    if (r == null) return null;
    return r.dirs[dirIndex.clamp(0, r.dirs.length - 1)];
  }

  List<String> get keypadKeys => keypadMode == 'abc' ? kAbcKeys : kNumKeys;

  String get ctaText {
    if (searching) return '검색 중…';
    if (query.isEmpty) return '버스 번호를 입력하세요';
    return '$query번 ${effectiveMode == SunMode.shade ? '그늘' : '햇살'} 계산하기';
  }

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
    searchError = null;
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
    searchError = null;
    notifyListeners();
  }

  /// 노선번호로 전국 TAGO 검색 → 결과에 따라 결과 화면 또는 방면 선택으로.
  Future<void> submitSearch() async {
    final q = query.trim();
    if (q.isEmpty || searching) return;

    searching = true;
    searchError = null;
    screen = AppScreen.loading;
    notifyListeners();

    BusRoute? route;
    try {
      route = routeCache[q] ?? await TagoRouteRepository.search(q);
    } catch (_) {
      route = null;
      searchError = '노선 정보를 불러오지 못했어요. 네트워크를 확인해 주세요.';
    }

    searching = false;
    if (route == null) {
      searchError ??= '"$q"번 노선을 찾을 수 없어요. 번호를 확인해 주세요.';
      screen = AppScreen.home;
      notifyListeners();
      return;
    }

    await _cacheRoute(route);
    chooseRoute(route);
  }

  void chooseRoute(BusRoute route) {
    resolvedRoute = route;
    if (route.dirs.length > 1) {
      screen = AppScreen.home;
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
    resolvedRoute = route;
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

  /// 현재 방면의 정류장 중 사용자 위치에서 가장 가까운 것 — TAGO가 준 실제
  /// 좌표(stopCoords)와 GPS 좌표를 하버사인으로 비교한다. 좌표가 없는 정류장
  /// (시드 데이터 등)이거나 위치를 못 얻었으면 null.
  ({int index, double meters})? get nearestStop {
    final dir = currentDir;
    final loc = location;
    if (dir == null || loc == null) return null;
    int? bestIdx;
    double? bestDist;
    for (var i = 0; i < dir.stops.length; i++) {
      final c = dir.coordAt(i);
      if (c == null) continue;
      final d = haversineMeters(lat1: loc.lat, lng1: loc.lon, lat2: c.lat, lng2: c.lng);
      if (bestDist == null || d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    if (bestIdx == null || bestDist == null) return null;
    return (index: bestIdx, meters: bestDist);
  }

  Future<void> useNearestStop() async {
    final dir = currentDir;
    if (dir == null) return;
    if (location == null) await refreshLocation();
    final near = nearestStop;
    final nearIdx = near?.index ?? (dir.stops.length > 1 ? 1 : 0);
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

  /// 즐겨찾기 탭 — 캐시에 있으면 바로, 없으면 로딩을 잠깐 보여주고 TAGO에서
  /// 받아온다 (예: 다른 기기에서 등록한 즐겨찾기를 처음 여는 경우).
  Future<void> openFavoriteResult(Favorite fav) async {
    var route = routeCache[fav.routeNo];
    if (route == null) {
      screen = AppScreen.loading;
      resultEntered = false;
      notifyListeners();
      try {
        route = await TagoRouteRepository.search(fav.routeNo);
      } catch (_) {
        route = null;
      }
      if (route == null) {
        searchError = '즐겨찾기한 ${fav.routeNo}번 노선을 불러오지 못했어요.';
        screen = AppScreen.home;
        notifyListeners();
        return;
      }
      await _cacheRoute(route);
    }

    resolvedRoute = route;
    dirIndex = fav.dirIndex.clamp(0, route.dirs.length - 1);
    boardIndex = fav.boardIndex;
    alightIndex = fav.alightIndex;
    resultEntered = false;
    screen = AppScreen.result;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 60));
    resultEntered = true;
    notifyListeners();
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
    if (location != null) unawaited(_loadNearestStation());
  }

  /// 홈 화면 "가까운 정류장" 캡션 — 실패해도 화면을 막지 않고 조용히 넘어간다.
  Future<void> _loadNearestStation() async {
    final loc = location;
    if (loc == null) return;
    nearbyStationLoading = true;
    notifyListeners();
    try {
      final stations = await TagoStationService.findNearby(lat: loc.lat, lng: loc.lon, numOfRows: 5);
      nearestKnownStation = stations.isEmpty ? null : stations.first;
    } catch (_) {
      nearestKnownStation = null;
    } finally {
      nearbyStationLoading = false;
      notifyListeners();
    }
  }
}
