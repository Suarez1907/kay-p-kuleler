#!/usr/bin/env python3
"""Kayıp Kuleler başlatıcı simgesi üretici.

Kaynak: art/icon-4096.png (4096², tam kare). Bu betik doğru boyutlarda
küçültülmüş PNG'leri yazar:

* Godot proje simgesi (icon.png) ve Android dışa aktarma katmanları
* Eski WebView uygulamasının mipmap / uyarlanabilir simgeleri
* Mağaza simgesi ve tarayıcı favicon'u

Uyarlanabilir ön plan, kristal ve kule tabanı daire maskesinde kesilmesin diye
özneyi tuvalin güvenli alanına (~%18 kenar payı) oturtur; kenarlar aynı
gradyanla doldurulur. Kare simgeler (proje, mağaza, favicon, eski başlatıcı)
kaynağın tamamıdır.

Kullanım: python3 tools/make_icons.py   (Pillow gerekir)
"""
import os
from collections import deque
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
MASTER = os.path.join(ROOT, 'art', 'icon-4096.png')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

# Özne tuvalin üstünde ~%6, altında ~%4 boşlukla duruyor. Android uyarlanabilir
# maskesi dış ~%17'yi kırptığı için ön plan %66 ölçekle ortaya alınır; böylece
# kristalin ucu ve kule tabanı daire maskesinin içinde pay bırakarak kalır.
ADAPTIVE_SCALE = 0.66
ADAPTIVE_CENTER = (0.50, 0.52)
SEAM_PAD = 0.035
SEAM_BLUR = 0.02

LEGACY = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
FOREGROUND = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}


def downscale(im, size):
    img = im
    while img.width // 2 >= size:
        img = img.resize((img.width // 2, img.height // 2), Image.Resampling.LANCZOS)
    if img.size != (size, size):
        img = img.resize((size, size), Image.Resampling.LANCZOS)
    return img


def save_png(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, 'PNG', optimize=True, compress_level=9)


def median_color(im, box):
    crop = im.crop(box)
    small = crop.resize((max(1, crop.width // 16), max(1, crop.height // 16)), Image.Resampling.BOX)
    raw = small.get_flattened_data() if hasattr(small, 'get_flattened_data') else small.getdata()
    pixels = sorted(raw, key=lambda p: p[0] + p[1] + p[2])
    return pixels[len(pixels) // 2][:3]


def hex_color(rgb):
    return '{:02X}{:02X}{:02X}'.format(*rgb)


def vertical_gradient(size, top, bottom):
    img = Image.new('RGB', (size, size))
    draw = ImageDraw.Draw(img)
    span = max(1, size - 1)
    for y in range(size):
        k = y / span
        color = tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(3))
        draw.line([(0, y), (size, y)], fill=color)
    return img


def adaptive_foreground(src, size):
    """Özneyi güvenli alana küçült, kenar piksellerini dışarı taşı, dikişi yumuşat."""
    sw = sh = max(1, int(round(size * ADAPTIVE_SCALE)))
    small = downscale(src, sw) if sw < src.width else src.resize((sw, sh), Image.Resampling.LANCZOS)
    if small.size != (sw, sh):
        small = small.resize((sw, sh), Image.Resampling.LANCZOS)
    cx, cy = ADAPTIVE_CENTER
    ox = int(round(size * 0.5 - cx * sw))
    oy = int(round(size * 0.5 - cy * sh))
    canvas = Image.new('RGB', (size, size))
    right = size - (ox + sw)
    bottom = size - (oy + sh)
    if oy > 0:
        canvas.paste(small.crop((0, 0, sw, 1)).resize((sw, oy), Image.Resampling.NEAREST), (ox, 0))
    if ox > 0:
        canvas.paste(small.crop((0, 0, 1, sh)).resize((ox, sh), Image.Resampling.NEAREST), (0, oy))
    if bottom > 0:
        canvas.paste(small.crop((0, sh - 1, sw, sh)).resize((sw, bottom), Image.Resampling.NEAREST), (ox, oy + sh))
    if right > 0:
        canvas.paste(small.crop((sw - 1, 0, sw, sh)).resize((right, sh), Image.Resampling.NEAREST), (ox + sw, oy))
    if ox > 0 and oy > 0:
        canvas.paste(small.crop((0, 0, 1, 1)).resize((ox, oy), Image.Resampling.NEAREST), (0, 0))
    if right > 0 and oy > 0:
        canvas.paste(small.crop((sw - 1, 0, sw, 1)).resize((right, oy), Image.Resampling.NEAREST), (ox + sw, 0))
    if ox > 0 and bottom > 0:
        canvas.paste(small.crop((0, sh - 1, 1, sh)).resize((ox, bottom), Image.Resampling.NEAREST), (0, oy + sh))
    if right > 0 and bottom > 0:
        canvas.paste(small.crop((sw - 1, sh - 1, sw, sh)).resize((right, bottom), Image.Resampling.NEAREST), (ox + sw, oy + sh))
    canvas.paste(small, (ox, oy))
    blur = canvas.filter(ImageFilter.GaussianBlur(radius=max(1.2, size * SEAM_BLUR)))
    mask = Image.new('L', (size, size), 0)
    pad = int(size * SEAM_PAD)
    ImageDraw.Draw(mask).rectangle([ox + pad, oy + pad, ox + sw - 1 - pad, oy + sh - 1 - pad], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=max(1.2, size * SEAM_BLUR)))
    return Image.composite(canvas, blur, mask)


def monochrome(fg):
    """Uyarlanabilir tek renk katmanı: öznenin beyaz silüeti, kenar dikişi hariç."""
    rgb = fg.convert('RGB')
    w, h = rgb.size
    px = rgb.load()
    samples = [px[x, 2] for x in range(0, w, 4)]
    samples.sort(key=lambda p: p[0] + p[1] + p[2])
    top = samples[len(samples) // 2]
    samples = [px[x, h - 3] for x in range(0, w, 4)]
    samples.sort(key=lambda p: p[0] + p[1] + p[2])
    bottom = samples[len(samples) // 2]
    mask = Image.new('L', (w, h), 0)
    mp = mask.load()
    margin = int(w * 0.045)
    for y in range(h):
        k = y / (h - 1)
        bg = tuple(top[i] + (bottom[i] - top[i]) * k for i in range(3))
        for x in range(w):
            if x < margin or y < margin or x >= w - margin or y >= h - margin:
                continue
            c = px[x, y]
            if abs(c[0] - bg[0]) + abs(c[1] - bg[1]) + abs(c[2] - bg[2]) > 48:
                mp[x, y] = 255
    # İnce halkalar gövdeye bağlansın; köşedeki dikiş artığı ayrı bileşen olarak düşsün.
    mask = mask.filter(ImageFilter.MaxFilter(5))
    pxm = mask.load()
    seed = None
    for y in range(h // 3, 2 * h // 3):
        for x in range(w // 3, 2 * w // 3):
            if pxm[x, y]:
                seed = (x, y)
                break
        if seed:
            break
    if seed:
        seen = bytearray(w * h)
        q = deque([seed])
        seen[seed[1] * w + seed[0]] = 1
        while q:
            x, y = q.popleft()
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if nx < 0 or ny < 0 or nx >= w or ny >= h:
                    continue
                i = ny * w + nx
                if seen[i] or not pxm[nx, ny]:
                    continue
                seen[i] = 1
                q.append((nx, ny))
        for y in range(h):
            row = y * w
            for x in range(w):
                if not seen[row + x]:
                    pxm[x, y] = 0
    soft = mask.filter(ImageFilter.GaussianBlur(1.1))
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    op = out.load()
    sp = soft.load()
    for y in range(h):
        for x in range(w):
            if sp[x, y] > 40:
                op[x, y] = (255, 255, 255, 255)
    return out


def circle_mask(size):
    big = size * 4
    mask = Image.new('L', (big, big), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, big - 1, big - 1], fill=255)
    return mask.resize((size, size), Image.Resampling.LANCZOS)


def circled(im):
    out = im.convert('RGBA')
    out.putalpha(circle_mask(im.width))
    return out


def background_xml(top, bottom):
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- tools/make_icons.py tarafından üretildi -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:pathData="M0,0 L108,0 L108,108 L0,108 Z">
        <aapt:attr name="android:fillColor">
            <gradient android:type="linear" android:startX="0" android:startY="0" android:endX="0" android:endY="108">
                <item android:offset="0" android:color="#FF{hex_color(top)}"/>
                <item android:offset="1" android:color="#FF{hex_color(bottom)}"/>
            </gradient>
        </aapt:attr>
    </path>
</vector>
'''


def adaptive_xml():
    return '''<?xml version="1.0" encoding="utf-8"?>
<!-- tools/make_icons.py tarafından üretildi -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
'''


def write_godot_icons(src, fg, top, bottom, mono, project):
    base = os.path.join(ROOT, project)
    save_png(downscale(src, 512), os.path.join(base, 'icon.png'))
    launch = os.path.join(base, 'launcher')
    save_png(downscale(src, 192), os.path.join(launch, 'icon_192.png'))
    save_png(downscale(fg, 432), os.path.join(launch, 'icon_foreground.png'))
    save_png(vertical_gradient(432, top, bottom), os.path.join(launch, 'icon_background.png'))
    # Godot 4.8 tek renk seçeneğini okur; 4.3 yok sayar. Dosya her iki projede de durur.
    save_png(downscale(mono, 432) if mono.width != 432 else mono, os.path.join(launch, 'icon_monochrome.png'))


def main():
    src = Image.open(MASTER).convert('RGB')
    if src.size != (4096, 4096):
        raise SystemExit(f'beklenen 4096², gelen {src.size}')
    w, h = src.size
    top = median_color(src, (0, 0, w, max(1, h // 30)))
    bottom = median_color(src, (0, h - max(1, h // 30), w, h))
    fg = adaptive_foreground(src, 2048)
    mono = monochrome(fg)

    write_godot_icons(src, fg, top, bottom, mono, 'godot-program')
    write_godot_icons(src, fg, top, bottom, mono, 'godot')

    for dpi, px in LEGACY.items():
        folder = os.path.join(RES, f'mipmap-{dpi}')
        save_png(downscale(src, px), os.path.join(folder, 'ic_launcher.png'))
        save_png(circled(downscale(src, px)), os.path.join(folder, 'ic_launcher_round.png'))
    for dpi, px in FOREGROUND.items():
        folder = os.path.join(RES, f'mipmap-{dpi}')
        save_png(downscale(fg, px), os.path.join(folder, 'ic_launcher_foreground.png'))
        save_png(downscale(mono, px), os.path.join(folder, 'ic_launcher_monochrome.png'))

    os.makedirs(os.path.join(RES, 'drawable'), exist_ok=True)
    os.makedirs(os.path.join(RES, 'mipmap-anydpi-v26'), exist_ok=True)
    with open(os.path.join(RES, 'drawable', 'ic_launcher_background.xml'), 'w', encoding='utf-8') as fh:
        fh.write(background_xml(top, bottom))
    old_fg = os.path.join(RES, 'drawable', 'ic_launcher_foreground.xml')
    if os.path.exists(old_fg):
        os.remove(old_fg)
    xml = adaptive_xml()
    for name in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        with open(os.path.join(RES, 'mipmap-anydpi-v26', name), 'w', encoding='utf-8') as fh:
            fh.write(xml)

    save_png(downscale(src, 512), os.path.join(ROOT, 'android', 'store', 'icon-512.png'))
    save_png(downscale(src, 32), os.path.join(ROOT, 'web', 'favicon.png'))
    print(f'simgeler üretildi (gradyan #{hex_color(top)} → #{hex_color(bottom)})')


if __name__ == '__main__':
    main()
