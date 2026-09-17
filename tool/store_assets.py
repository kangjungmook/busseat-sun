#!/usr/bin/env python3
"""플레이스토어 등록 자산 생성 — 아이콘(512px)과 피처 그래픽(1024x500).

콘솔에 올릴 것을 손으로 만들면 규격을 놓치기 쉬워서 스크립트로 둔다.
    python3 tool/store_assets.py

만드는 것:
  store/play-icon-512.png       512x512, 투명도 없음 (모서리를 브랜드색으로 채움)
  store/play-feature-1024x500.png

스크린샷은 여기서 만들지 않는다 — 실제 기기에서 실제 노선을 검색한 화면이어야
한다. 규격만 적어두면: 세로 1080x2340 권장, 최소 2장, PNG 또는 JPEG.
"""
from PIL import Image, ImageDraw, ImageFont

ICON_SRC = 'assets/icon/app_icon.png'
FONT = 'assets/fonts/PretendardVariable.ttf'

# 앱 팔레트와 같은 값 (lib/theme/tokens.dart)
ORANGE = (245, 158, 11)      # 햇살 모드 primary — 아이콘 바탕
INDIGO = (79, 70, 229)       # 그늘 모드 primary
GROUND = (250, 250, 249)     # kLightSurface.background
INK = (41, 37, 36)
MUTED = (120, 113, 108)


def font(size, weight='Bold'):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass  # 가변 축이 없으면 기본 굵기로 둔다
    return f


def build_icon(out='store/play-icon-512.png'):
    """512x512 스토어 아이콘.

    원본은 모서리가 투명한 둥근 사각형이다. 플레이는 자체 마스크를 씌우므로
    투명한 모서리를 그대로 두면 가장자리가 지저분해진다. 같은 주황으로 채워
    꽉 찬 정사각형으로 만든다.
    """
    src = Image.open(ICON_SRC).convert('RGBA')
    bg = Image.new('RGBA', src.size, ORANGE + (255,))
    bg.alpha_composite(src)
    bg.convert('RGB').resize((512, 512), Image.LANCZOS).save(out)
    return out


def build_feature(out='store/play-feature-1024x500.png'):
    """1024x500 피처 그래픽.

    플레이가 자리에 따라 위아래를 잘라 쓰므로 중요한 것은 가운데 띠에 모은다.
    그라데이션·장식은 쓰지 않는다 — 한 번에 읽혀야 하는 그림이다.

    오른쪽은 이 앱이 하는 일 자체를 그린다: 버스 옆면의 창 두 개, 해가 드는
    쪽과 그늘인 쪽. 색은 앱 안에서 쓰는 것과 같다(그늘=인디고, 볕=주황).
    """
    W, H = 1024, 500
    # 아래쪽이 비어 보여서 광학 중심을 살짝 내린다.
    CY = H // 2 + 18
    im = Image.new('RGB', (W, H), GROUND)
    d = ImageDraw.Draw(im)

    # ---------- 왼쪽: 이름과 한 줄 설명 ----------
    ICON = 96
    icon = Image.open(ICON_SRC).convert('RGBA').resize((ICON, ICON), Image.LANCZOS)
    icon_y = CY - 96
    im.paste(icon, (72, icon_y), icon)
    d.text((72 + ICON + 24, icon_y + 10), '햇살좌석', font=font(58, 'ExtraBold'), fill=INK)

    d.text((74, CY + 24), '버스 타기 직전 3초.', font=font(29, 'Medium'), fill=MUTED)
    d.text((74, CY + 66), '어느 쪽 창가에 앉을지만 알려줍니다.', font=font(29, 'Medium'), fill=MUTED)

    # ---------- 오른쪽: 버스 옆면 ----------
    BX0, BX1 = 624, 968              # 차체
    BY0, BY1 = CY - 118, CY + 96
    d.rounded_rectangle([BX0, BY0, BX1, BY1], radius=28, fill=(255, 255, 255),
                        outline=(231, 229, 228), width=3)

    # 창 두 개. 가운데 기둥(빈 공간)이 버스처럼 보이게 한다.
    WY0, WY1 = BY0 + 30, BY1 - 74
    lw0, lw1 = BX0 + 28, BX0 + 158   # 왼쪽 창 (그늘)
    rw0, rw1 = BX0 + 186, BX1 - 28   # 오른쪽 창 (볕)
    d.rounded_rectangle([lw0, WY0, lw1, WY1], radius=14, fill=INDIGO)
    d.rounded_rectangle([rw0, WY0, rw1, WY1], radius=14, fill=(253, 224, 181))

    # 바퀴 — 실루엣이 버스로 읽히게 하는 최소한의 단서
    for cx in (BX0 + 78, BX1 - 78):
        d.ellipse([cx - 16, BY1 - 18, cx + 16, BY1 + 14], fill=(214, 211, 209))

    # 창 아래 라벨
    def label(x0, x1, top, bottom, fill):
        tw = d.textlength(top, font=font(27, 'Bold'))
        d.text((x0 + (x1 - x0 - tw) / 2, WY1 + 12), top, font=font(27, 'Bold'), fill=fill)
        sw = d.textlength(bottom, font=font(21, 'Medium'))
        d.text((x0 + (x1 - x0 - sw) / 2, WY1 + 44), bottom, font=font(21, 'Medium'), fill=MUTED)

    label(lw0, lw1, '왼쪽', '그늘', INDIGO)
    label(rw0, rw1, '오른쪽', '볕 듦', (180, 83, 9))

    # ---------- 해 ----------
    # 차체 밖 오른쪽 위에 둬서 "이 방향에서 볕이 든다"가 읽히게 한다.
    sx, sy, r = 940, BY0 - 26, 30
    d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=ORANGE)
    for dx, dy in ((0, -1), (1, 0), (0.7, -0.7), (-0.7, -0.7), (0.7, 0.7)):
        d.line([sx + dx * (r + 10), sy + dy * (r + 10),
                sx + dx * (r + 22), sy + dy * (r + 22)], fill=ORANGE, width=5)

    im.save(out)
    return out


if __name__ == '__main__':
    for p in (build_icon(), build_feature()):
        print('✓', p)
