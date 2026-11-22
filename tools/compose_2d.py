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
FONT = os.path.join(ROOT, "godot-program", "fonts", "Nunito.ttf")


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


def store(subject):
    img = grad((1024, 500), (255, 206, 168), (120, 104, 196))
    img.alpha_composite(Image.open(subject).convert("RGBA").resize((1024, 500)))
    dr = ImageDraw.Draw(img)
    title = font(92, 1000)
    sub = font(30, 850)
    for txt, y in (("KAYIP", 92), ("KULELER", 186)):
        dr.text((60, y + 7), txt, font=title, fill=(84, 52, 160))
        dr.text((60, y), txt, font=title, fill=(255, 255, 255), stroke_width=4, stroke_fill=(120, 80, 210))
    dr.text((64, 310), "Robo'yu programla,", font=sub, fill=(255, 255, 255), stroke_width=2, stroke_fill=(84, 52, 160))
    dr.text((64, 350), "bilgisayarı parça parça topla!", font=sub, fill=(255, 255, 255), stroke_width=2, stroke_fill=(84, 52, 160))
    out = os.path.join(ROOT, "store", "feature_graphic.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img.convert("RGB").save(out, optimize=True)


if __name__ == "__main__":
    {"icon": icon, "store": store}[sys.argv[1]](sys.argv[2])
