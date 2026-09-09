import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sunseat/models/tago.dart';

/// 좌표기반근접정류소 응답 파싱 — **2026-09-09 실제 응답 원문**을 그대로 넣는다.
///
/// 활용가이드 예제(XML)와 실제 JSON 응답이 두 군데 다르다. 둘 다 여기서 고정해
/// 둔다. 이 경로는 실패해도 화면에 아무 표시가 없어서(캡션이 안 뜰 뿐이다)
/// 눈으로는 절대 못 잡는다.
///
/// 요청: gpsLati=36.3&gpsLong=127.3&numOfRows=5 (명세 예제 좌표, 대전 근처)
const _realResponse = r'''
{"response":{"header":{"resultCode":"00","resultMsg":"NORMAL SERVICE."},"body":{"items":{"item":[
{"citycode":25,"gpslati":36.298546,"gpslong":127.29593,"nodeid":"DJB8002012","nodenm":"성북3통굿개말길","nodeno":40600},
{"citycode":25,"gpslati":36.29852,"gpslong":127.29574,"nodeid":"DJB8002013","nodenm":"성북3통굿개말길","nodeno":40590}]},
"numOfRows":5,"pageNo":1,"totalCount":2}}}
''';

List<Map<String, dynamic>> _items() {
  final body = jsonDecode(_realResponse)['response']['body'];
  return (body['items']['item'] as List).cast<Map<String, dynamic>>();
}

void main() {
  test('실제 응답 2건이 모두 파싱된다', () {
    final stations = _items().map(TagoNearbyStation.fromJson).whereType<TagoNearbyStation>().toList();
    expect(stations, hasLength(2));
    expect(stations.first.nodeId, 'DJB8002012');
    expect(stations.first.nodeName, '성북3통굿개말길');
    expect(stations.first.lat, closeTo(36.298546, 1e-6));
    expect(stations.first.lng, closeTo(127.29593, 1e-6));
  });

  test('숫자로 오는 필드도 문자열로 받는다 — citycode/nodeno가 JSON number다', () {
    // 명세 예제는 XML이라 전부 텍스트로 보이지만, _type=json이면
    // "citycode":25 처럼 따옴표 없이 온다. _pick이 toString()으로 받아내는
    // 덕분에 통과한다 — 여기를 `as String?` 캐스트로 "정리"하면 전부 null이
    // 되고, 캡션이 조용히 사라진다.
    final s = _items().map(TagoNearbyStation.fromJson).first!;
    expect(s.cityCode, '25');
    expect(s.nodeNo, '40600');
  });

  test('nodeno는 실제로 온다 — 명세 응답표에는 빠져 있다', () {
    // 활용가이드 v1.0의 이 오퍼레이션 응답 명세는 gpslati/gpslong/nodeid/
    // nodenm/citycode 다섯 개만 적어뒀는데, 실제로는 nodeno도 온다.
    // 모델이 옵션으로 두고 있어서 어느 쪽이든 깨지지 않는다.
    expect(_items().every((m) => m.containsKey('nodeno')), isTrue);
  });

  test('좌표가 없는 항목은 버린다 — 거리 계산이 불가능하다', () {
    expect(TagoNearbyStation.fromJson({'nodeid': 'X', 'nodenm': '좌표없음'}), isNull);
  });
}
