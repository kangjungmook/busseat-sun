#!/usr/bin/env bash
# GitHub Pages(docs/)용 웹 빌드.
#
# 손으로 하면 빠뜨리는 단계가 셋 있어서 스크립트로 고정한다:
#   1) 키 없이 빌드 — 공개 저장소에 API 키가 박히면 안 된다
#   2) CanvasKit을 같이 올리고 그쪽을 보게 한다 — 기본값인 gstatic CDN이
#      느리거나 막히면 **아무 오류 없이 흰 화면**이 된다. 앱 코드가 실행되기
#      전 단계라 화면에 안내조차 못 띄운다
#   3) 서비스 워커 등록 제거 — 계속 다시 올리는 중이라, 워커가 이전 빌드를
#      캐시해서 새로고침해도 옛 화면이 보이는 편이 훨씬 나쁘다
set -euo pipefail
cd "$(dirname "$0")/.."

BASE_HREF="${1:-/busseat-sun/}"

echo "▶ 빌드 (dart-define 없이 — 키가 들어가면 안 된다)"
flutter build web --release --base-href "$BASE_HREF"

echo "▶ docs/ 교체"
rm -rf docs
cp -r build/web docs
rm -f docs/flutter_service_worker.js docs/.last_build_id
touch docs/.nojekyll

echo "▶ CanvasKit 정리 — 쓰는 것만 남긴다 (37MB → 약 12MB)"
# dart2js + canvaskit 렌더러가 실제로 받는 것은 이 넷뿐이다.
# skwasm/wimp/webparagraph 변형과 .symbols 는 이 빌드에서 쓰이지 않는다.
KEEP=$(mktemp -d)
mkdir -p "$KEEP/chromium"
cp docs/canvaskit/canvaskit.js docs/canvaskit/canvaskit.wasm "$KEEP/"
cp docs/canvaskit/chromium/canvaskit.js docs/canvaskit/chromium/canvaskit.wasm "$KEEP/chromium/"
rm -rf docs/canvaskit
mv "$KEEP" docs/canvaskit

echo "▶ 부트스트랩 패치"
python3 - <<'PY'
p = 'docs/flutter_bootstrap.js'
s = open(p).read()
i = s.find('_flutter.loader.load({')
assert i >= 0, 'loader 호출을 찾지 못했다 — Flutter가 부트스트랩 형식을 바꿨는지 확인할 것'
s = s[:i] + '''// 서비스 워커 등록은 뺐고, CanvasKit은 같이 올린 사본을 쓴다.
// 이유는 tool/build_pages.sh 주석 참고.
_flutter.loader.load({config: {canvasKitBaseUrl: "canvaskit/"}});
'''
open(p, 'w').write(s)
PY

echo "▶ 키 유출 점검"
if [ -f secrets/dart_defines.json ]; then
  python3 - <<'PY'
import json, pathlib, sys
keys = [v for v in json.load(open('secrets/dart_defines.json')).values()
        if isinstance(v, str) and v and not v.startswith('http')]
hit = False
for f in pathlib.Path('docs').rglob('*'):
    if not f.is_file():
        continue
    blob = f.read_bytes()
    for k in keys:
        if k.encode() in blob:
            print(f'  ✗ 키가 들어갔다: {f}')
            hit = True
sys.exit(1 if hit else 0)
PY
  echo "  ✓ 키 없음"
else
  echo "  – secrets/dart_defines.json 이 없어 건너뜀 (원래 키 없이 빌드된다)"
fi

echo "✓ docs/ 준비 완료 ($(du -sh docs | cut -f1))"
