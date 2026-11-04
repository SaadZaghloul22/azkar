import math, os
from PIL import Image, ImageDraw, ImageFilter

S = 1024
EMERALD = (14, 107, 78)
EMERALD_D = (8, 70, 50)
GOLD = (214, 176, 62)
GOLD_L = (240, 214, 130)

def gradient(size):
    im = Image.new("RGB", (size, size), EMERALD)
    px = im.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            px[x, y] = tuple(int(EMERALD[i] * (1 - t) + EMERALD_D[i] * t) for i in range(3))
    return im

def star_points(cx, cy, r, rot=0.0):
    pts = []
    for sq in (0, math.pi / 4):
        poly = []
        for i in range(4):
            a = rot + sq + i * math.pi / 2 + math.pi / 4
            poly.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        pts.append(poly)
    return pts

def draw_mark(d, cx, cy, scale, bg):
    r = 300 * scale
    for poly in star_points(cx, cy, r):
        d.polygon(poly, fill=GOLD)
    for poly in star_points(cx, cy, r * 0.86):
        d.polygon(poly, fill=GOLD_L)
    for poly in star_points(cx, cy, r * 0.80):
        d.polygon(poly, fill=bg)
    # crescent
    cr = r * 0.40
    d.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=GOLD_L)
    off = cr * 0.36
    d.ellipse([cx - cr + off, cy - cr - off * 0.35, cx + cr + off, cy + cr - off * 0.35], fill=bg)
    # small star beside crescent
    sr = r * 0.12
    sx, sy = cx + cr * 0.42, cy - cr * 0.05
    for poly in star_points(sx, sy, sr, rot=math.pi / 8):
        d.polygon(poly, fill=GOLD_L)

def full_icon(size=S, rounded=True):
    big = 2048
    im = gradient(big).convert("RGBA")
    d = ImageDraw.Draw(im)
    draw_mark(d, big / 2, big / 2, 2.0, EMERALD)
    im = im.resize((size, size), Image.LANCZOS)
    if rounded:
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * 0.22), fill=255)
        im.putalpha(mask)
    return im

def foreground(size=432):
    big = 2048
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # adaptive icons crop to the inner 66%, keep the mark within it
    draw_mark(d, big / 2, big / 2, 1.30, EMERALD)
    return im.resize((size, size), Image.LANCZOS)

res = "android/app/src/main/res"
for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    os.makedirs(f"{res}/mipmap-{name}", exist_ok=True)
    full_icon(px).save(f"{res}/mipmap-{name}/ic_launcher.png")
for name, px in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
    foreground(px).save(f"{res}/mipmap-{name}/ic_launcher_foreground.png")
os.makedirs(f"{res}/mipmap-anydpi-v26", exist_ok=True)
open(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", "w").write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''')
open(f"{res}/values/colors.xml", "w").write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0E6B4E</color>
    <color name="splash_background">#F7F4EC</color>
    <color name="splash_background_night">#0A1C15</color>
</resources>
''')
os.makedirs("store", exist_ok=True)
full_icon(512, rounded=False).convert("RGB").save("store/icon-512.png")
full_icon(1024).save("store/icon-preview.png")
print("icons done")
