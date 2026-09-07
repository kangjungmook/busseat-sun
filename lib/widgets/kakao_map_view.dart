import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
///
/// asset을 `loadFlutterAsset`으로 바로 열지 않고 문자열로 읽어
/// `loadHtmlString(baseUrl: ...)`으로 띄우는 이유는 [KakaoJsConfig.sdkDomain]
/// 문서 참고 — 요약하면 `loadFlutterAsset`은 오리진이 `file://`이라 카카오
/// 콘솔에 등록할 수 없고, 그래서 JS SDK 도메인 검증을 통과하지 못한다.
///
/// 콘솔에서 `앱` → `플랫폼 키` → `JavaScript 키` → `JavaScript SDK 도메인`에
/// [KakaoJsConfig.sdkDomain]과 똑같은 값을 등록해야 한다. 2026-07-21부터는
/// 도메인 등록과 별개로 카카오맵 API 활성화도 필요하다 — README "지도 SDK" 절 참고.
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
      );
    if (KakaoJsConfig.isConfigured) _loadMapHtml();
  }

  /// asset HTML을 직접 읽어 [KakaoJsConfig.sdkDomain] 오리진으로 띄운다.
  Future<void> _loadMapHtml() async {
    final html = await rootBundle.loadString('assets/map/kakao_map.html');
    if (!mounted) return;
    await _controller.loadHtmlString(html, baseUrl: KakaoJsConfig.sdkDomain);
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
