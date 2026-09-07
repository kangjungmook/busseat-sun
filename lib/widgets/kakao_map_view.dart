import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/kakao_js_config.dart';

/// 지도에 마커로 찍을 정류장 하나.
class MapStop {
  final String name;
  final double lat;
  final double lng;

  const MapStop({required this.name, required this.lat, required this.lng});

  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lng': lng};
}

/// 카카오맵 JavaScript SDK를 WebView에 올린 실제 지도.
///
/// 미리 채워둔 [KakaoJsConfig.jsKey]가 없으면 안내 문구만 보여준다.
/// 도메인은 카카오 디벨로퍼스 → 앱 → `플랫폼 키` → `JavaScript 키` 섹션의
/// `JavaScript SDK 도메인`에 `https://appassets.androidplatform.net`을 등록해야
/// 한다 (Android WebView의 `loadFlutterAsset`가 앱 내 asset을 서빙하는 가상
/// 도메인). 2026-07-21부터는 도메인 등록과 별개로 앱 관리 페이지에서 카카오맵
/// API 활성화도 필요하다 — 자세한 건 README "지도 SDK" 절 참고.
/// iOS `loadFlutterAsset`가 실제로 어떤 오리진을 쓰는지는 이 세션에서
/// 기기로 확인하지 못했다 — iOS 빌드 시 등록 도메인을 다시 확인해야 한다.
///
/// [stops]가 바뀌었을 때 다시 그리려면 호출하는 쪽에서 노선/방면이 바뀔 때
/// 위젯 [Key]도 함께 바꿔줘야 한다 (WebView를 새로 띄우는 게 JS를 다시
/// 부르는 것보다 단순하고 확실하다 — map_screen.dart 참고).
class KakaoMapView extends StatefulWidget {
  final double lat;
  final double lng;
  final int level;
  final List<MapStop> stops;

  const KakaoMapView({super.key, required this.lat, required this.lng, this.level = 4, this.stops = const []});

  @override
  State<KakaoMapView> createState() => _KakaoMapViewState();
}

class _KakaoMapViewState extends State<KakaoMapView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await _controller.runJavaScript(
              'initMap("${KakaoJsConfig.jsKey}", ${widget.lat}, ${widget.lng}, ${widget.level});',
            );
            if (widget.stops.isNotEmpty) {
              final stopsJson = jsonEncode(widget.stops.map((s) => s.toJson()).toList());
              // kakao.maps.load의 콜백이 비동기라 initMap 직후엔 아직 map이
              // 없을 수 있다 — setStops는 map==null이면 조용히 무시하고
              // 리턴하니, 짧게 한 번 더 시도해 SDK 로드 타이밍을 흡수한다.
              await _controller.runJavaScript('setStops($stopsJson);');
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) await _controller.runJavaScript('setStops($stopsJson);');
            }
          },
        ),
      )
      ..loadFlutterAsset('assets/map/kakao_map.html');
  }

  @override
  Widget build(BuildContext context) {
    if (!KakaoJsConfig.isConfigured) {
      return const ColoredBox(
        color: Color(0xFFEDEAE4),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '카카오맵 JavaScript 키가 설정되지 않았습니다.\nsecrets/dart_defines.json의 KAKAO_JS_KEY를 채워주세요.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return WebViewWidget(controller: _controller);
  }
}
