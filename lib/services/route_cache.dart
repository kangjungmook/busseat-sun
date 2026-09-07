import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/route.dart';

/// TAGO에서 한 번 조회한 [BusRoute]를 노선번호 기준으로 저장해둔다.
/// - "오늘" 화면이 즐겨찾기를 앱 실행 즉시 보여줘야 해서, 매번 네트워크를
///   기다리게 할 수 없다 — 캐시가 있으면 그걸로 바로 그리고, 뒤에서 조용히
///   최신화한다.
/// - 같은 세션 안에서 같은 노선을 다시 검색할 때도 API를 또 부르지 않는다.
class RouteCache {
  static const _key = 'sunseat_route_cache_v1';
  static Map<String, BusRoute>? _memory;

  static Future<Map<String, BusRoute>> _ensureLoaded() async {
    if (_memory != null) return _memory!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _memory = {};
      return _memory!;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _memory = map.map((k, v) => MapEntry(k, BusRoute.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      _memory = {};
    }
    return _memory!;
  }

  static Future<BusRoute?> get(String routeNo) async {
    final cache = await _ensureLoaded();
    return cache[routeNo];
  }

  /// 앱 시작 시 AppState가 동기 읽기용으로 통째로 가져가는 용도.
  static Future<Map<String, BusRoute>> allCached() => _ensureLoaded();

  static Future<void> put(BusRoute route) async {
    final cache = await _ensureLoaded();
    cache[route.no] = route;
    _memory = cache;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(cache.map((k, v) => MapEntry(k, v.toJson()))));
  }
}
