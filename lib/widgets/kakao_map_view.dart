import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/kakao_js_config.dart';

/// 카카오맵 JavaScript SDK를 WebView에 올린 실제 지도.
///
/// 미리 채워둔 [KakaoJsConfig.jsKey]가 없으면 안내 문구만 보여준다.
/// 도메인은 카카오 디벨로퍼스 → 플랫폼 → Web에
/// `https://appassets.androidplatform.net` 을 등록해야 한다
/// (Android WebView의 `loadFlutterAsset`가 앱 내 asset을 서빙하는 가상 도메인).
/// iOS `loadFlutterAsset`가 실제로 어떤 오리진을 쓰는지는 이 세션에서
/// 기기로 확인하지 못했다 — iOS 빌드 시 등록 도메인을 다시 확인해야 한다.
class KakaoMapView extends StatefulWidget {
  final double lat;
  final double lng;
  final int level;

  const KakaoMapView({super.key, required this.lat, required this.lng, this.level = 4});

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
          onPageFinished: (_) {
            _controller.runJavaScript(
              'initMap("${KakaoJsConfig.jsKey}", ${widget.lat}, ${widget.lng}, ${widget.level});',
            );
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
