import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// 방면 하나 — 기점→종점, 진행 방위, 정류장.
class RouteDir {
  final String name; // '서울역 방면'
  final String from; // 기점
  final String to; // 종점
  final double bearing; // 진행 방위 (도, 0=북, 시계방향) — 좌석 계산의 핵심
  final List<String> stops; // 표시용 주요 정류장
  final int stopCount; // 실제 정류장 수

  const RouteDir({
    required this.name,
    required this.from,
    required this.to,
    required this.bearing,
    required this.stops,
    required this.stopCount,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'from': from,
        'to': to,
        'bearing': bearing,
        'stops': stops,
        'stopCount': stopCount,
      };

  factory RouteDir.fromJson(Map<String, dynamic> json) => RouteDir(
        name: json['name'] as String,
        from: json['from'] as String,
        to: json['to'] as String,
        bearing: (json['bearing'] as num).toDouble(),
        stops: (json['stops'] as List).map((e) => e as String).toList(),
        stopCount: json['stopCount'] as int,
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

/// 시드 데이터 — 프로토타입과 동일. 실제 검색은 TagoRouteRepository(실시간
/// TAGO API)가 우선이고, 이건 "가까운 정류장" 예시 칩과 오프라인/API 실패 시
/// 대체용으로만 쓴다.
final List<BusRoute> kSeedRoutes = [
  const BusRoute(no: '9401', kind: '직행좌석', durationMin: 42, dirs: [
    RouteDir(
      name: '서울역 방면',
      from: '강남역',
      to: '종로2가',
      bearing: 15,
      stops: ['강남역', '신논현', '서울역', '종로2가'],
      stopCount: 10,
    ),
    RouteDir(
      name: '경기광주 방면',
      from: '종로2가',
      to: '강남역',
      bearing: 195,
      stops: ['종로2가', '서울역', '신논현', '강남역'],
      stopCount: 11,
    ),
  ]),
  const BusRoute(no: '9404', kind: '직행좌석', durationMin: 51, dirs: [
    RouteDir(
      name: '신사 방면',
      from: '분당수내',
      to: '신사역',
      bearing: 340,
      stops: ['수내', '판교', '양재', '신사'],
      stopCount: 9,
    ),
  ]),
  const BusRoute(no: '3401', kind: '광역', durationMin: 38, dirs: [
    RouteDir(
      name: '강남역 방면',
      from: '장지',
      to: '강남역',
      bearing: 290,
      stops: ['장지', '수서', '대치', '강남역'],
      stopCount: 12,
    ),
    RouteDir(
      name: '복정 방면',
      from: '강남역',
      to: '복정',
      bearing: 110,
      stops: ['강남역', '대치', '수서', '복정'],
      stopCount: 12,
    ),
  ]),
  const BusRoute(no: '1550', kind: '광역', durationMin: 47, dirs: [
    RouteDir(
      name: '사당 방면',
      from: '수원역',
      to: '사당역',
      bearing: 35,
      stops: ['수원역', '과천', '남태령', '사당'],
      stopCount: 8,
    ),
  ]),
  const BusRoute(no: '140', kind: '간선', durationMin: 44, dirs: [
    RouteDir(
      name: '도봉 방면',
      from: 'AT센터',
      to: '수유',
      bearing: 5,
      stops: ['AT센터', '신사', '명동', '수유'],
      stopCount: 24,
    ),
    RouteDir(
      name: 'AT센터 방면',
      from: '수유',
      to: 'AT센터',
      bearing: 185,
      stops: ['수유', '명동', '신사', 'AT센터'],
      stopCount: 24,
    ),
  ]),
  const BusRoute(no: '472', kind: '간선', durationMin: 36, dirs: [
    RouteDir(
      name: '신림 방면',
      from: '송파',
      to: '신림',
      bearing: 265,
      stops: ['송파', '잠실', '사당', '신림'],
      stopCount: 19,
    ),
  ]),
];

BusRoute findRoute(String no) => kSeedRoutes.firstWhere(
      (r) => r.no == no,
      orElse: () => kSeedRoutes.first,
    );
