import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/route.dart';

/// 즐겨찾기 로컬 저장. 로그인 시엔 서버 동기화로 교체 (핸드오프 8절).
class FavoritesStore {
  static const _key = 'sunseat_favorites_v1';

  static Future<List<Favorite>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return Favorite(
        routeNo: m['routeNo'] as String,
        dirIndex: m['dirIndex'] as int,
        label: m['label'] as String,
        from: m['from'] as String,
        to: m['to'] as String,
        boardIndex: m['boardIndex'] as int? ?? 0,
        alightIndex: m['alightIndex'] as int?,
      );
    }).toList();
  }

  static Future<void> save(List<Favorite> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(favorites
        .map((f) => {
              'routeNo': f.routeNo,
              'dirIndex': f.dirIndex,
              'label': f.label,
              'from': f.from,
              'to': f.to,
              'boardIndex': f.boardIndex,
              'alightIndex': f.alightIndex,
            })
        .toList());
    await prefs.setString(_key, raw);
  }
}
