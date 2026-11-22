#!/usr/bin/env python3
"""blender_2d_generator.py'nin render ettiği şeffaf özneleri gradyan arka planla birleştirir (Pillow).

    python3 tools/compose_2d.py icon  <özne.png>   → art/icon-4096.png  (+ tools/make_icons.py)
    python3 tools/compose_2d.py store <özne.png>   → store/feature_graphic.png (1024×500, başlık yazısıyla)
"""
import os
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
FONT = os.path.join(ROOT, "godot-program", "fonts", "ChakraPetch-Bold.ttf")
FONT_MED = os.path.join(ROOT, "godot-program", "fonts", "ChakraPetch-SemiBold.ttf")


def grad(size, top, bottom):
    w, h = size
    col = Image.new("RGB", (1, h))
    for y in range(h):
        k = y / (h - 1)
        col.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(3)))
    return col.resize((w, h)).convert("RGBA")


def font(sz, wght):
    f = ImageFont.truetype(FONT, sz)
    try:
        f.set_variation_by_axes([wght])
    except Exception:
        pass
    return f


def icon(subject):
    sub = Image.open(subject).convert("RGBA")
    if sub.size != (4096, 4096):
        sub = sub.resize((4096, 4096), Image.Resampling.LANCZOS)
    bg = grad(sub.size, (253, 203, 171), (171, 151, 210))
    bg.alpha_composite(sub)
    os.makedirs(os.path.join(ROOT, "art"), exist_ok=True)
    bg.convert("RGB").save(os.path.join(ROOT, "art", "icon-4096.png"), optimize=True)
    subprocess.run([sys.executable, os.path.join(HERE, "make_icons.py")], check=True)


def blueprint_bg(w, h):
    """Blueprint v2 zemini: lacivert, 24 px ızgara, her 5 karede cyan ana çizgi, kenar vinyeti."""
    img = Image.new("RGBA", (w, h), (7, 18, 36, 255))
    d = ImageDraw.Draw(img, "RGBA")
    for x in range(0, w, 24):
        major = (x // 24) % 5 == 0
        d.line([(x, 0), (x, h)], fill=(0, 229, 255, 14) if major else (43, 76, 126, 20))
    for y in range(0, h, 24):
        major = (y // 24) % 5 == 0
        d.line([(0, y), (w, y)], fill=(0, 229, 255, 14) if major else (43, 76, 126, 20))
    vig = Image.new("L", (w, h), 0)
    vd = ImageDraw.Draw(vig)
    for k in range(40):
        a = int(255 * (k / 40) ** 2 * 0.5)
        vd.rectangle([k * 4, k * 3, w - k * 4, h - k * 3], outline=255 - a)
    return img


def store(subject):
    img = blueprint_bg(1024, 500)
    img.alpha_composite(Image.open(subject).convert("RGBA").resize((1024, 500)))
    dr = ImageDraw.Draw(img)
    dr.text((62, 108), "SYS // KAYIP", font=font(22, 600), fill=(0, 229, 255))
    dr.text((58, 132), "KULELER", font=font(104, 700), fill=(241, 245, 249))
    sub = ImageFont.truetype(FONT_MED, 26)
    dr.text((62, 262), "Robo'yu programla,", font=sub, fill=(127, 166, 201))
    dr.text((62, 296), "bilgisayarı parça parça topla.", font=sub, fill=(127, 166, 201))
    # pahlı cyan rozet
    x0, y0, x1, y1, c = 62, 352, 372, 404, 10
    dr.polygon([(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)], fill=(0, 229, 255))
    dr.text((x0 + 22, y0 + 10), "▶  100 SEVİYE · GÜNLÜK", font=ImageFont.truetype(FONT, 22), fill=(5, 19, 34))
    out = os.path.join(ROOT, "store", "feature_graphic.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img.convert("RGB").save(out, optimize=True)


if __name__ == "__main__":
    {"icon": icon, "store": store}[sys.argv[1]](sys.argv[2])
