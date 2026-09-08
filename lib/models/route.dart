import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// WGS84 좌표 하나. TAGO 정류소 좌표(gpslati/gpslong), 사용자 GPS 위치에 쓴다.
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint({required this.lat, required this.lng});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );
}

/// 방면 하나 — 기점→종점, 진행 방위, 정류장.
class RouteDir {
  final String name; // '서울역 방면'
  final String from; // 기점
  final String to; // 종점
  final double bearing; // 진행 방위 (도, 0=북, 시계방향) — 좌석 계산의 핵심
  final List<String> stops; // 표시용 주요 정류장
  final int stopCount; // 실제 정류장 수
  // stops[i]의 좌표. TAGO가 실제로 준 정류소만 채워지고 그 외는 null이다
  // (좌표 없이 만들면 빈 리스트 — coordAt이 안전하게 null을 돌려준다).
  final List<GeoPoint?> stopCoords;

  const RouteDir({
    required this.name,
    required this.from,
    required this.to,
    required this.bearing,
    required this.stops,
    required this.stopCount,
    this.stopCoords = const [],
  });

  GeoPoint? coordAt(int i) => i >= 0 && i < stopCoords.length ? stopCoords[i] : null;

  /// 지도에 그릴 수 있는(좌표가 있는) 정류장만 이름과 함께 뽑는다.
  List<({String name, GeoPoint point})> get mappableStops {
    final out = <({String name, GeoPoint point})>[];
    for (var i = 0; i < stops.length; i++) {
      final p = coordAt(i);
      if (p != null) out.add((name: stops[i], point: p));
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'from': from,
        'to': to,
        'bearing': bearing,
        'stops': stops,
        'stopCount': stopCount,
        'stopCoords': stopCoords.map((c) => c?.toJson()).toList(),
      };

  factory RouteDir.fromJson(Map<String, dynamic> json) => RouteDir(
        name: json['name'] as String,
        from: json['from'] as String,
        to: json['to'] as String,
        bearing: (json['bearing'] as num).toDouble(),
        stops: (json['stops'] as List).map((e) => e as String).toList(),
        stopCount: json['stopCount'] as int,
        stopCoords: (json['stopCoords'] as List?)
                ?.map((e) => e == null ? null : GeoPoint.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// 버스 노선.
class BusRoute {
  final String no; // '9401'
  final String kind; // '직행좌석' | '광역' | '간선'
  final int durationMin; // 전 구간 소요
  final List<RouteDir> dirs; // 1~2개

  const BusRoute({
    required this.no,
    required this.kind,
    required this.durationMin,
    required this.dirs,
  });

  // '직행좌석'/'광역' 계열은 빨강, 그 외(간선/지선/마을버스 등 TAGO routetp
  // 원문 그대로 들어올 수 있음)는 파랑 — 시드 데이터와 실제 TAGO 데이터 둘 다 커버.
  Color get badgeColor => (kind.contains('직행좌석') || kind.contains('광역')) ? kBadgeExpress : kBadgeTrunk;

  Map<String, dynamic> toJson() => {
        'no': no,
        'kind': kind,
        'durationMin': durationMin,
        'dirs': dirs.map((d) => d.toJson()).toList(),
      };

  factory BusRoute.fromJson(Map<String, dynamic> json) => BusRoute(
        no: json['no'] as String,
        kind: json['kind'] as String,
        durationMin: json['durationMin'] as int,
        dirs: (json['dirs'] as List).map((e) => RouteDir.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// 즐겨찾기 — 노선의 특정 방면 + 승/하차 구간.
class Favorite {
  final String routeNo;
  final int dirIndex;
  final String label; // '출근' | '퇴근' | '기타'
  final String from; // 탑승 정류장명
  final String to; // 하차 정류장명
  final int boardIndex;
  final int? alightIndex;

  const Favorite({
    required this.routeNo,
    required this.dirIndex,
    required this.label,
    required this.from,
    required this.to,
    this.boardIndex = 0,
    this.alightIndex,
  });
}
