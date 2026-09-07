import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/tago_config.dart';
import '../services/tago_bus_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// 개발용 화면 — TAGO API를 실제로 호출해보고 결과(성공/실패, 원본 응답)를
/// 그대로 보여준다. 이 세션은 data.go.kr 접속이 막혀 있어 직접 호출해서
/// 검증하지 못했기 때문에, 실기기에서 이 화면으로 테스트해보고 결과를
/// 알려주면 lib/services/tago_bus_service.dart를 바로 맞출 수 있다.
class TagoDebugScreen extends StatefulWidget {
  final AppPalette palette;

  const TagoDebugScreen({super.key, required this.palette});

  @override
  State<TagoDebugScreen> createState() => _TagoDebugScreenState();
}

class _TagoDebugScreenState extends State<TagoDebugScreen> {
  final _cityCodeCtrl = TextEditingController(text: '11');
  final _routeNoCtrl = TextEditingController(text: '9401');
  final _routeIdCtrl = TextEditingController();

  bool _loading = false;
  String _output = '아래 버튼을 눌러 테스트하세요.';

  Future<void> _run(Future<String> Function() task) async {
    setState(() {
      _loading = true;
      _output = '요청 중…';
    });
    try {
      final result = await task();
      setState(() => _output = result);
    } catch (e) {
      setState(() => _output = '❌ 실패\n\n$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<String> _testCityCodes() async {
    final cities = await TagoBusService.getCityCodes();
    if (cities.isEmpty) return '✅ 응답은 왔지만 목록이 비어 있음 (필드명이 다를 수 있음)';
    return '✅ 도시 ${cities.length}개\n\n' + cities.map((c) => '${c.code}\t${c.name}').join('\n');
  }

  Future<String> _testRouteSearch() async {
    final routes = await TagoBusService.searchRoutesByNumber(
      cityCode: _cityCodeCtrl.text.trim(),
      routeNo: _routeNoCtrl.text.trim(),
    );
    if (routes.isEmpty) return '✅ 응답은 왔지만 목록이 비어 있음 (도시코드가 안 맞거나 필드명이 다를 수 있음)';
    return '✅ 노선 ${routes.length}개\n\n' + routes.map((r) => 'routeId=${r.routeId}  routeNo=${r.routeNo}  type=${r.routeType}\n  ${r.startNodeName} → ${r.endNodeName}\n  raw=${r.raw}').join('\n\n');
  }

  Future<String> _testRouteStops() async {
    final stops = await TagoBusService.getRouteStops(
      cityCode: _cityCodeCtrl.text.trim(),
      routeId: _routeIdCtrl.text.trim(),
    );
    if (stops.isEmpty) return '✅ 응답은 왔지만 목록이 비어 있음';
    return '✅ 정류소 ${stops.length}개\n\n' + stops.map((s) => '${s.order ?? '-'}. ${s.nodeName} (${s.nodeId}) lat=${s.lat} lng=${s.lng}').join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final palette = widget.palette;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconCircleButton(icon: const Icon(Icons.arrow_back), color: palette.text, onTap: () => state.goto(AppScreen.settings)),
                  const SizedBox(width: 6),
                  Text('TAGO API 테스트', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 19, fontWeight: FontWeight.w800, color: palette.text)),
                ],
              ),
            ),
            if (!TagoConfig.isConfigured)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: palette.badColor.withOpacity(.15), borderRadius: BorderRadius.circular(12)),
                child: Text('TAGO_API_KEY가 설정되지 않았습니다. secrets/dart_defines.json을 채우고 --dart-define-from-file로 실행하세요.', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12.5, color: palette.text)),
              ),
            Row(
              children: [
                Expanded(child: _field('cityCode', _cityCodeCtrl, palette)),
                const SizedBox(width: 8),
                Expanded(child: _field('routeNo', _routeNoCtrl, palette)),
              ],
            ),
            const SizedBox(height: 8),
            _field('routeId (2단계에서 나온 값 복사)', _routeIdCtrl, palette),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _btn('1. 도시코드 목록', () => _run(_testCityCodes), palette),
                _btn('2. 노선 검색', () => _run(_testRouteSearch), palette),
                _btn('3. 정류소(좌표) 조회', () => _run(_testRouteStops), palette),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: palette.subtle, borderRadius: BorderRadius.circular(14)),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _loading ? '요청 중…' : _output,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: palette.text, height: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, AppPalette palette) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap, AppPalette palette) {
    return Material(
      color: palette.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(label, style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12.5, fontWeight: FontWeight.w800, color: palette.onPrimary)),
        ),
      ),
    );
  }
}
