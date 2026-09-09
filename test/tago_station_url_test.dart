import 'package:flutter_test/flutter_test.dart';
import 'package:sunseat/services/tago_station_service.dart';

/// TAGO 정류소정보조회 서비스 요청 URL이 활용가이드 v1.0과 맞는지 본다.
///
/// 이게 왜 테스트할 가치가 있냐면, 여기서 오타 하나가 나면 **화면에는 아무
/// 일도 안 일어나기 때문**이다. `_loadNearestStation`이 실패를 삼키고 캐시
/// 기반 대체 경로로 조용히 넘어가서, "가까운 정류장"이 그냥 안 뜰 뿐이다.
/// 실제로 `getCrdntPrxmtStaionList`(Staion)로 부르고 있었고, 그 실패를
/// "활용신청이 안 됐나 보다"로 이틀간 오진했다.
///
/// 명세(1.1 나. 상세기능 목록 / 2) 좌표기반근접정류소 목록조회):
/// ```
/// http://apis.data.go.kr/1613000/BusSttnInfoInqireService/getCrdntPrxmtSttnList
///   ?serviceKey=...&gpsLati=36.3&gpsLong=127.3&numOfRows=10&pageNo=1&_type=xml
/// ```
void main() {
  final uri = TagoStationService.nearbyUri(lat: 36.3, lng: 127.3, numOfRows: 5);

  test('오퍼레이션 이름은 getCrdntPrxmtSttnList — Staion 아님', () {
    expect(uri.path, '/1613000/BusSttnInfoInqireService/getCrdntPrxmtSttnList');
  });

  test('좌표 파라미터는 gpsLati/gpsLong (대문자 L) — 응답 필드명과 대소문자가 다르다', () {
    expect(uri.queryParameters['gpsLati'], '36.3');
    expect(uri.queryParameters['gpsLong'], '127.3');
    expect(uri.queryParameters.containsKey('gpslati'), isFalse);
  });

  test('명세가 요구하는 나머지 파라미터가 다 있다', () {
    expect(uri.queryParameters.keys, containsAll(<String>['serviceKey', 'pageNo', 'numOfRows', '_type']));
    expect(uri.queryParameters['numOfRows'], '5');
  });

  test('명세에 없는 파라미터는 보내지 않는다 (cityCode는 이 오퍼레이션 소관이 아니다)', () {
    expect(uri.queryParameters.containsKey('cityCode'), isFalse);
  });
}
