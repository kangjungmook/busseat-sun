import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/route.dart';
import '../models/tago.dart';
import 'tago_route_repository.dart';

/// 웹 미리보기용 **예시 노선**.
///
/// 공개 웹 빌드는 키 없이 컴파일되므로 검색이 동작하지 않고, 그래서 이 앱이
/// 실제로 답을 내놓는 화면(결과·좌석지도·구간지정·지도)에 **아무도 들어갈 수
/// 없었습니다.** 앱을 보여줄 방법이 없으니 화면 절반이 없는 것과 같습니다.
///
/// 그렇다고 좌표를 지어내지는 않았습니다. 이 에셋은
/// `getRouteAcctoThrghSttnList`를 실제로 호출해 받은 **응답 원문 그대로**입니다
/// (2026-09-15, 세종 `cityCode=12` / `routeId=SJB271000805`, B7 집현동→비하종점,
/// 정류장 39개). 파싱도 조립도 검색 경로와 **똑같은 코드**([TagoRouteStop.fromJson],
/// [TagoRouteRepository.buildRoute])를 탑니다. 그래서 여기서 보이는 좌석 추천과
/// 구간별 일사는 흉내가 아니라 **실제 계산 결과**입니다.
///
/// 다만 사용자에게는 예시라고 분명히 말해야 합니다 — 지금 이 시각 저 버스가
/// 저기를 달리고 있다는 뜻이 아니고, 노선이 바뀌어도 이 파일은 안 바뀝니다.
/// 화면에서 `예시` 표시를 떼지 마세요.
class DemoRouteService {
  static const String assetPath = 'assets/demo/route_b7_sejong_cheongju.json';

  /// 화면에 붙이는 노선번호. 실제 번호(B7)를 그대로 쓰되 예시임은 UI가 밝힙니다.
  static const String routeNo = 'B7';

  static BusRoute? _cached;

  /// 실패하면 null — 미리보기 편의 기능이라 앱을 막지 않습니다.
  static Future<BusRoute?> load() async {
    if (_cached != null) return _cached;
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      final items = decoded['response']?['body']?['items']?['item'];
      if (items is! List) return null;

      final stops = items
          .cast<Map<String, dynamic>>()
          .map(TagoRouteStop.fromJson)
          .whereType<TagoRouteStop>()
          .toList();

      return _cached = TagoRouteRepository.buildRoute(
        routeNo: routeNo,
        routeType: '광역급행버스',
        stops: stops,
      );
    } catch (_) {
      return null;
    }
  }
}
