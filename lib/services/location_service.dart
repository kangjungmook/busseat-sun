import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double lat;
  final double lon;
  final double accuracyM;

  const LocationResult({required this.lat, required this.lon, required this.accuracyM});

  String get accuracyLabel => '±${accuracyM.round()}m';
}

/// 현재 위치 조회. 실제 정류장 매칭은 TOPIS API 연동 시 좌표로 질의한다 (핸드오프 8절 참고).
class LocationService {
  static Future<LocationResult?> current() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return LocationResult(lat: pos.latitude, lon: pos.longitude, accuracyM: pos.accuracy);
  }
}
