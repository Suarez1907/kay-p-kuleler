#!/usr/bin/env python3
"""Kayıp Kuleler başlatıcı simgesi üretici.
Uyarlanabilir simge (vektör ön plan + arka plan) ve API 24-25 için PNG mipmap'ler üretir.
Kullanım: python3 tools/make_icons.py   (Pillow gerekir)"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
RES = os.path.join(ROOT, 'android/app/src/main/res')
BG_TOP, BG_BOT = '#FDE2D0', '#C8B6E8'

# 108x108 tuval üzerinde şekiller (güvenli alan: merkezde 66x66)
SHAPES = [
    # (renk, çokgen)
    ('#F7E4C8', [(54, 33), (73, 44), (54, 55), (35, 44)]),            # büyük küp üst
    ('#E8B3A3', [(35, 44), (54, 55), (54, 77), (35, 66)]),            # sol yüz
    ('#D99BA0', [(54, 55), (73, 44), (73, 66), (54, 77)]),            # sağ yüz
    ('#7CC6C4', [(54, 55), (63.5, 49.5), (63.5, 60.5), (54, 66)]),    # döner şerit
    ('#FFFAF2', [(48, 34), (54, 30.5), (60, 34), (60, 41), (54, 44.5), (48, 41)]),  # robo gövde
    ('#3B3555', [(50, 36), (54, 33.7), (58, 36), (58, 38.5), (54, 40.8), (50, 38.5)]),  # yüz
    ('#FF7F66', [(54, 17), (58.5, 23), (54, 29), (49.5, 23)]),        # hedef kristali
]
EYES = [(52.3, 37.4), (55.7, 37.4)]

def vector_foreground():
    paths = '\n'.join(
        f'    <path android:fillColor="{c}" android:pathData="M{pts[0][0]},{pts[0][1]} ' +
        ' '.join(f'L{x},{y}' for x, y in pts[1:]) + ' Z"/>' for c, pts in SHAPES)
    eyes = '\n'.join(f'    <path android:fillColor="#7FF3FF" android:pathData="M{x-0.9},{y} a0.9,0.9 0 1,0 1.8,0 a0.9,0.9 0 1,0 -1.8,0"/>' for x, y in EYES)
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- tools/make_icons.py tarafından üretildi -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
{paths}
{eyes}
</vector>
'''

def vector_background():
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- tools/make_icons.py tarafından üretildi -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:pathData="M0,0 L108,0 L108,108 L0,108 Z">
        <aapt:attr name="android:fillColor">
            <gradient android:type="linear" android:startX="0" android:startY="0" android:endX="0" android:endY="108">
                <item android:offset="0" android:color="#FF{BG_TOP[1:]}"/>
                <item android:offset="1" android:color="#FF{BG_BOT[1:]}"/>
            </gradient>
        </aapt:attr>
    </path>
</vector>
'''

def hexrgb(h):
    h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def raster(size, shape='square'):
    S = size * 4
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    bg = Image.new('RGBA', (S, S))
    t, b = hexrgb(BG_TOP), hexrgb(BG_BOT)
    d = ImageDraw.Draw(bg)
    for y in range(S):
        k = y / (S - 1)
        d.line([(0, y), (S, y)], fill=tuple(int(t[i] + (b[i] - t[i]) * k) for i in range(3)) + (255,))
    # legacy simgede 108 tuvalin ortadaki ~80 birimini göster
    crop0, span = 14, 80
    f = S / span
    d = ImageDraw.Draw(bg)
    for c, pts in SHAPES:
        d.polygon([((x - crop0) * f, (y - crop0) * f) for x, y in pts], fill=hexrgb(c) + (255,))
    for x, y in EYES:
        r = 0.9 * f; cx, cy = (x - crop0) * f, (y - crop0) * f
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=hexrgb('#7FF3FF') + (255,))
    mask = Image.new('L', (S, S), 0)
    md = ImageDraw.Draw(mask)
    if shape == 'round':
        md.ellipse([0, 0, S - 1, S - 1], fill=255)
    elif shape == 'full':
        md.rectangle([0, 0, S, S], fill=255)
    else:
        md.rounded_rectangle([0, 0, S - 1, S - 1], radius=S * 0.18, fill=255)
    img.paste(bg, (0, 0), mask)
    return img.resize((size, size), Image.LANCZOS)

def main():
    os.makedirs(f'{RES}/drawable', exist_ok=True)
    os.makedirs(f'{RES}/mipmap-anydpi-v26', exist_ok=True)
    open(f'{RES}/drawable/ic_launcher_foreground.xml', 'w').write(vector_foreground())
    open(f'{RES}/drawable/ic_launcher_background.xml', 'w').write(vector_background())
    adaptive = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
'''
    for n in ('ic_launcher', 'ic_launcher_round'):
        open(f'{RES}/mipmap-anydpi-v26/{n}.xml', 'w').write(adaptive)
    for dpi, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        os.makedirs(f'{RES}/mipmap-{dpi}', exist_ok=True)
        raster(px).save(f'{RES}/mipmap-{dpi}/ic_launcher.png')
        raster(px, 'round').save(f'{RES}/mipmap-{dpi}/ic_launcher_round.png')
    os.makedirs(os.path.join(ROOT, 'android/store'), exist_ok=True)
    raster(512, 'full').save(os.path.join(ROOT, 'android/store/icon-512.png'))
    print('simgeler üretildi')

if __name__ == '__main__':
    main()
