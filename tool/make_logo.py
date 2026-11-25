#!/usr/bin/env python3
"""App logo: the word «أذكار» in gold Amiri Bold on emerald (option 3).

Generates every place the logo appears, from one shaped outline of the word:
  - launcher icons (legacy rounded square + adaptive foreground / monochrome)
  - assets/images/logo.png (splash and onboarding)
  - store/listing/icon-512.png (Google Play, full-bleed square)
  - res/drawable/ic_stat_azkar.xml (status-bar notification icon, white vector)
Needs: pip install uharfbuzz fonttools playwright (Chromium is preinstalled in CI images).
Run from the repo root: python3 tool/make_logo.py
"""
import base64
import os

import uharfbuzz as hb
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, 'assets', 'fonts', 'Amiri_700Bold.ttf')
WORD = 'أذكار'
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')


def word_path():
    """SVG path of the shaped word, y pointing down, origin at the bbox top-left."""
    data = open(FONT, 'rb').read()
    face = hb.Face(data)
    font = hb.Font(face)
    buf = hb.Buffer()
    buf.add_str(WORD)
    buf.guess_segment_properties()
    hb.shape(font, buf, {})
    tt = TTFont(FONT)
    gs = tt.getGlyphSet()
    order = tt.getGlyphOrder()
    pen = SVGPathPen(gs)
    x = 0
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        name = order[info.codepoint]
        # flip y (font units are y-up) and place the glyph at the pen position
        tp = TransformPen(pen, (1, 0, 0, -1, x + pos.x_offset, -pos.y_offset))
        gs[name].draw(tp)
        x += pos.x_advance
    d = pen.getCommands()
    # bbox from the drawn outline
    from fontTools.pens.boundsPen import BoundsPen
    bp = BoundsPen(gs)
    x = 0
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        gs[order[info.codepoint]].draw(TransformPen(bp, (1, 0, 0, -1, x + pos.x_offset, -pos.y_offset)))
        x += pos.x_advance
    return d, bp.bounds  # (xmin, ymin, xmax, ymax) in flipped units


D, (X0, Y0, X1, Y1) = word_path()
W, H = X1 - X0, Y1 - Y0

GRAD = '''<defs>
 <linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#15855F"/><stop offset="1" stop-color="#073B29"/></linearGradient>
 <linearGradient id="au" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F6E39B"/><stop offset=".55" stop-color="#D9B44A"/><stop offset="1" stop-color="#B98E28"/></linearGradient>
 <radialGradient id="glow" cx=".5" cy=".42" r=".6"><stop offset="0" stop-color="#fff" stop-opacity=".16"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
</defs>'''


def word(cx, cy, width, fill='url(#au)'):
    s = width / W
    return (f'<g transform="translate({cx - width / 2:.2f},{cy - H * s / 2:.2f}) scale({s:.5f}) '
            f'translate({-X0:.2f},{-Y0:.2f})"><path d="{D}" fill="{fill}"/></g>')


def dots(cx, y, r, gap, fill='#E9D79A'):
    return ''.join(f'<circle cx="{cx + k * gap:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{fill}"/>' for k in (-1, 0, 1))


def full(rounded=True, frame=True):
    rx = 112 if rounded else 0
    out = GRAD + f'<rect width="512" height="512" rx="{rx}" fill="url(#g)"/><rect width="512" height="512" rx="{rx}" fill="url(#glow)"/>'
    if frame:
        out += '<rect x="64" y="64" width="384" height="384" rx="70" fill="none" stroke="url(#au)" stroke-width="6"/>'
    return out + word(256, 238, 300) + dots(256, 372, 7, 30)


def foreground():
    # Adaptive icon: 108dp canvas, launchers mask to ~66dp; keep the word well inside.
    return GRAD + word(256, 240, 232) + dots(256, 338, 6, 24)


def render(svg, size, path, transparent=True):
    html = (f'<html><body style="margin:0;background:transparent">'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 512 512">{svg}</svg>'
            f'</body></html>')
    page.set_viewport_size({'width': size, 'height': size})
    page.set_content(html)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    page.screenshot(path=path, omit_background=transparent)


with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    for name, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        render(full(), px, f'{RES}/mipmap-{name}/ic_launcher.png')
    for name, px in {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}.items():
        render(foreground(), px, f'{RES}/mipmap-{name}/ic_launcher_foreground.png')
    render(full(), 384, os.path.join(ROOT, 'assets', 'images', 'logo.png'))
    render(full(rounded=False), 512, os.path.join(ROOT, 'store', 'listing', 'icon-512.png'), transparent=False)
    render(full(), 1024, os.path.join(ROOT, 'store', 'icon-preview.png'))
    browser.close()

# Status-bar icon: white silhouette of the word (Android tints it), centred in 24dp.
pad = 0.08
side = max(W, H) * (1 + 2 * pad)
tx = (side - W) / 2 - X0
ty = (side - H) / 2 - Y0
pen_d = D  # path in flipped font units
open(f'{RES}/drawable/ic_stat_azkar.xml', 'w', encoding='utf-8').write(f'''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="{side:.1f}" android:viewportHeight="{side:.1f}">
    <!-- The word «أذكار» (Amiri Bold), generated by tool/make_logo.py -->
    <group android:translateX="{tx:.1f}" android:translateY="{ty:.1f}">
        <path android:fillColor="#FFFFFFFF" android:pathData="{pen_d}" />
    </group>
</vector>
''')
print('ok', W, H)
