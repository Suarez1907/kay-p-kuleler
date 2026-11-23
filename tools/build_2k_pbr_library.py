#!/usr/bin/env python3
"""Kayıp Kuleler — gerçek 2K PBR doku ve 2K stüdyo HDRI kütüphanesi.

    python3 tools/build_2k_pbr_library.py [--offline]

Çıktı:
  godot-program/assets/textures/pbr/<set>_2k/{albedo,normal,roughness,ao[,metallic]}.jpg   (2048×2048)
  godot-program/assets/hdri/{studio_softbox_2k,workshop_warm_2k}.exr                       (2048×1024)
  tools/pbr_2k_report.json   (kaynak, lisans, boyutlar)

Kaynaklar (CC0): Poly Haven API (api.polyhaven.com/files/<id>) ve ambientCG (ambientcg.com/get?file=<id>_2K-JPG.zip).
Ağ yoksa ya da bir dosya inemezse betik durmaz: o set numpy/Pillow ile prosedürel 2K üretilir (fBm, fırça çizgisi,
Sobel normal, boşluk AO). PCB devre ve altın kontak setleri her zaman prosedüreldir (oyuna özgü).
Normal haritaları OpenGL (+Y yukarı) kuralındadır; Godot da bunu bekler.
"""
import io
import json
import os
import sys
import urllib.request
import zipfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

N = 2048
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PBR = os.path.join(ROOT, "godot-program", "assets", "textures", "pbr")
HDRI = os.path.join(ROOT, "godot-program", "assets", "hdri")
OFFLINE = "--offline" in sys.argv
UA = {"User-Agent": "kayip-kuleler-asset-builder/1.0"}
report = {"sets": {}, "hdri": {}}

# (çıktı seti, kaynak türü, kimlik, prosedürel yedek)
SETS = [
    ("brushed_aluminum_2k", "acg", "Metal012", "brushed"),
    ("copper_metal_2k", "acg", "Metal057A", "copper"),
    ("epoxy_black_2k", "acg", "Plastic012A", "epoxy"),
    ("ceramic_matte_2k", "acg", "Porcelain001", "ceramic"),
    ("workshop_desk_2k", "ph", "dark_wood", "wood"),
]
HDRIS = [("studio_softbox_2k", "studio_small_08"), ("workshop_warm_2k", "photo_studio_loft_hall")]


def fetch(url, timeout=120):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def to_2k(img, mode):
    img = img.convert(mode)
    if img.size != (N, N):
        img = img.resize((N, N), Image.LANCZOS)
    return img


def save_jpg(img, path, q=93):
    img.save(path, quality=q, subsampling=0, optimize=True)


# ---------------------------------------------------------------------------
# prosedürel yardımcılar (hepsi periyodik → döşenebilir)
rng = np.random.default_rng(2026)


def fbm(beta=2.0, aniso=(1.0, 1.0), seed=0):
    r = np.random.default_rng(seed)
    w = r.standard_normal((N, N)) + 1j * r.standard_normal((N, N))
    fx = np.fft.fftfreq(N)[None, :] * aniso[0]
    fy = np.fft.fftfreq(N)[:, None] * aniso[1]
    f = np.sqrt(fx ** 2 + fy ** 2)
    f[0, 0] = 1.0
    img = np.real(np.fft.ifft2(w / f ** (beta / 2)))
    img -= img.min()
    return img / (img.max() + 1e-9)


def sobel_normal(h, strength):
    """Sarmalı Sobel türevi → OpenGL normal (0..1)."""
    def sh(a, dy, dx):
        return np.roll(np.roll(a, dy, 0), dx, 1)
    gx = (sh(h, -1, -1) + 2 * sh(h, 0, -1) + sh(h, 1, -1)) - (sh(h, -1, 1) + 2 * sh(h, 0, 1) + sh(h, 1, 1))
    gy = (sh(h, -1, -1) + 2 * sh(h, -1, 0) + sh(h, -1, 1)) - (sh(h, 1, -1) + 2 * sh(h, 1, 0) + sh(h, 1, 1))
    n = np.dstack([gx * strength, -gy * strength, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def cavity_ao(h, radius=24, amount=1.6):
    """Yükseklikten boşluk AO: bulanık ortalamanın altında kalan oyuklar kararır."""
    im = Image.fromarray((h * 255).astype(np.uint8))
    blur = np.asarray(im.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32) / 255.0
    return np.clip(1.0 - np.maximum(0.0, blur - h) * amount, 0.0, 1.0)


def u8(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def tint(base, var, amt):
    b = hexrgb(base)
    return np.clip(b[None, None, :] * (1 - amt + amt * 2 * var[..., None]), 0, 1)


def write_set(name, albedo, normal, rough, ao, metal=None, source="procedural"):
    d = os.path.join(PBR, name)
    os.makedirs(d, exist_ok=True)
    maps = {"albedo": albedo, "normal": normal, "roughness": rough, "ao": ao}
    if metal is not None:
        maps["metallic"] = metal
    for k, v in maps.items():
        img = v if isinstance(v, Image.Image) else u8(v)
        img = to_2k(img, "RGB" if k in ("albedo", "normal") else "L")
        save_jpg(img, os.path.join(d, k + ".jpg"), 95 if k == "normal" else 92)
    report["sets"][name] = {"source": source, "maps": sorted(maps.keys()), "size": [N, N],
                            "bytes": sum(os.path.getsize(os.path.join(d, k + ".jpg")) for k in maps)}
    print("  %-22s %-34s %s" % (name, source, ",".join(sorted(maps.keys()))))


def procedural(name, kind):
    if kind == "brushed":
        h = fbm(1.2, (1.0, 80.0), 1) * 0.8 + fbm(0.6, (1, 1), 2) * 0.2
        write_set(name, tint("#c3c8cf", h, 0.10), sobel_normal(h, 3.0), 0.26 + 0.16 * h, cavity_ao(h, 12, 0.8),
                  np.full((N, N), 1.0))
    elif kind == "copper":
        p = fbm(3.0, (1, 1), 3)
        sc = fbm(1.0, (1.0, 30.0), 4)
        h = p * 0.6 + sc * 0.4
        write_set(name, tint("#c8794a", p, 0.16), sobel_normal(h, 2.5), 0.22 + 0.28 * p, cavity_ao(h), np.full((N, N), 1.0))
    elif kind == "epoxy":
        e = fbm(0.25, (1, 1), 6)
        big = fbm(3.0, (1, 1), 7)
        write_set(name, tint("#1b1c21", big, 0.22), sobel_normal(e * 0.4, 6.0), 0.62 + 0.14 * e, cavity_ao(e, 6, 0.6))
    elif kind == "ceramic":
        c = fbm(1.6, (1, 1), 11)
        speck = (rng.random((N, N)) > 0.998).astype(float)
        write_set(name, tint("#e8e2d6", c, 0.06) * (1 - speck[..., None] * 0.35), sobel_normal(c * 0.4, 3.0),
                  0.72 + 0.12 * c, cavity_ao(c, 16, 0.6))
    elif kind == "wood":
        y = np.linspace(0, 1, N, endpoint=False)[:, None]
        warp = fbm(2.6, (1, 1), 21) * 0.08
        grain = np.sin((y + warp) * np.pi * 2 * 64) * 0.5 + 0.5
        fine = fbm(1.0, (1.0, 40.0), 22)
        h = grain * 0.6 + fine * 0.4
        alb = tint("#3b2416", h, 0.25)
        write_set(name, alb, sobel_normal(h, 2.0), 0.48 + 0.2 * fine, cavity_ao(h, 10, 0.7))


# ---------------------------------------------------------------------------
# oyuna özgü prosedürel setler
def _wrap_draw(draw_fn):
    """Döşenebilirlik: ilkel şekil 3×3 ötelemeyle çizilir (kenardan taşan kısım karşı kenara sarar)."""
    for ox in (-N, 0, N):
        for oy in (-N, 0, N):
            draw_fn(ox, oy)


def pcb_circuit():
    r = np.random.default_rng(42)
    # katmanlar: yükseklik (bakır yollar kabarık), maske (0 lehim maskesi, 1 bakır/altın), silkscreen
    height = Image.new("L", (N, N), 0)
    metal = Image.new("L", (N, N), 0)
    silk = Image.new("L", (N, N), 0)
    dh, dm, ds = ImageDraw.Draw(height), ImageDraw.Draw(metal), ImageDraw.Draw(silk)
    # bakır yollar: 0/45/90 derece kırılımlı, maskenin altında (yükseklik var, metal yok)
    for _ in range(260):
        x, y = r.integers(0, N), r.integers(0, N)
        w = int(r.choice([6, 8, 10, 14]))
        pts = [(x, y)]
        for _ in range(r.integers(2, 6)):
            d = r.choice([0, 1, 2, 3, 4, 5, 6, 7])
            L = int(r.integers(40, 260))
            dx, dy = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)][d]
            x, y = x + dx * L, y + dy * L
            pts.append((x, y))
        _wrap_draw(lambda ox, oy: dh.line([(a + ox, b + oy) for a, b in pts], fill=150, width=w, joint="curve"))
        # uçta altın via
        ex, ey = pts[-1]
        rr = w + 6
        _wrap_draw(lambda ox, oy: (dh.ellipse([ex - rr + ox, ey - rr + oy, ex + rr + ox, ey + rr + oy], fill=210),
                                   dm.ellipse([ex - rr + ox, ey - rr + oy, ex + rr + ox, ey + rr + oy], fill=255),
                                   dh.ellipse([ex - rr / 2.6 + ox, ey - rr / 2.6 + oy, ex + rr / 2.6 + ox, ey + rr / 2.6 + oy], fill=20)))
    # SMD ped dizileri (açık bakır/altın) + bileşen silkscreen çerçeveleri ve etiketleri
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 26)
    except OSError:
        font = ImageFont.load_default()
    for k in range(70):
        x, y = int(r.integers(0, N)), int(r.integers(0, N))
        nx, ny = int(r.integers(2, 9)), int(r.choice([1, 2]))
        pw, ph, gap = 18, 34, 12
        bw, bh = nx * (pw + gap) + 16, ny * (ph + 60) + 10
        _wrap_draw(lambda ox, oy: ds.rectangle([x - 10 + ox, y - 14 + oy, x + bw + ox, y + bh + oy], outline=255, width=4))
        for i in range(nx):
            for j in range(ny):
                px, py = x + i * (pw + gap), y + j * (ph + 60)
                _wrap_draw(lambda ox, oy: (dm.rectangle([px + ox, py + oy, px + pw + ox, py + ph + oy], fill=255),
                                           dh.rectangle([px + ox, py + oy, px + pw + ox, py + ph + oy], fill=230)))
        lbl = "%s%d" % (r.choice(["R", "C", "U", "Q", "D", "L", "J"]), r.integers(1, 99))
        _wrap_draw(lambda ox, oy: ds.text((x + ox, y + bh + 6 + oy), lbl, fill=255, font=font))
    # montaj delikleri
    for k in range(10):
        x, y, rr = int(r.integers(0, N)), int(r.integers(0, N)), 26
        _wrap_draw(lambda ox, oy: (dm.ellipse([x - rr + ox, y - rr + oy, x + rr + ox, y + rr + oy], fill=255),
                                   dh.ellipse([x - rr + ox, y - rr + oy, x + rr + ox, y + rr + oy], fill=200),
                                   dh.ellipse([x - 12 + ox, y - 12 + oy, x + 12 + ox, y + 12 + oy], fill=0)))
    h = np.asarray(height.filter(ImageFilter.GaussianBlur(1.6)), dtype=np.float32) / 255.0
    m = np.asarray(metal.filter(ImageFilter.GaussianBlur(0.8)), dtype=np.float32) / 255.0
    s = np.asarray(silk.filter(ImageFilter.GaussianBlur(0.7)), dtype=np.float32) / 255.0
    noise = fbm(0.4, (1, 1), 43)
    mask_col = tint("#0e3b25", noise, 0.12)                       # koyu zümrüt lehim maskesi
    trace_col = tint("#1d6a40", noise, 0.10)                      # maske altından görünen bakır yol (açık yeşil)
    gold = tint("#d8b04a", fbm(2.0, (1, 1), 44), 0.10)
    copper_under = np.clip((h - 0.05) * 3.0, 0, 1)[..., None] * (1 - m[..., None])
    alb = mask_col * (1 - copper_under) + trace_col * copper_under
    alb = alb * (1 - m[..., None]) + gold * m[..., None]
    alb = alb * (1 - s[..., None] * 0.92) + np.array([0.93, 0.93, 0.9])[None, None, :] * s[..., None] * 0.92
    rough = 0.42 + 0.1 * noise
    rough = rough * (1 - m) + (0.22 + 0.08 * noise) * m
    rough = rough * (1 - s) + 0.75 * s
    hh = h * 0.7 + s * 0.15 + noise * 0.04
    write_set("pcb_circuit_2k", alb, sobel_normal(hh, 5.0), rough, cavity_ao(hh, 8, 1.2), m, "procedural (PCB)")


def gold_contacts():
    # kart kenarı: dikey altın parmaklar, aralarında yeşil maske; parmak üstü ince fırça izi ve aşınma
    x = np.arange(N)[None, :]
    period, finger = 64, 46
    fx = (x % period) < finger
    fy = np.ones((N, 1), dtype=bool)
    m = (fx & fy).astype(np.float32)
    m = np.asarray(u8(m).filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255.0
    brush = fbm(1.0, (1.0, 90.0), 51)
    wear = fbm(2.4, (1, 1), 52)
    gold = tint("#e2b64c", brush * 0.7 + wear * 0.3, 0.12)
    mask = tint("#103f28", fbm(0.5, (1, 1), 53), 0.1)
    alb = gold * m[..., None] + mask * (1 - m[..., None])
    # yuvarlatılmış parmak kenarları için yükseklik
    edge = np.asarray(u8(m).filter(ImageFilter.GaussianBlur(5)), dtype=np.float32) / 255.0
    h = edge * 0.8 + brush * 0.06 * m
    rough = (0.16 + 0.12 * brush + 0.1 * np.clip(wear - 0.7, 0, 1)) * m + 0.45 * (1 - m)
    write_set("gold_contacts_2k", alb, sobel_normal(h, 6.0), rough, cavity_ao(h, 6, 0.8), m, "procedural (altın kontak)")


# ---------------------------------------------------------------------------
def from_polyhaven(name, aid):
    files = json.loads(fetch("https://api.polyhaven.com/files/" + aid))
    want = {"albedo": ["Diffuse", "diffuse", "diff"], "normal": ["nor_gl"], "roughness": ["Rough", "rough"], "ao": ["AO", "ao"],
            "metallic": ["Metal", "metal"]}
    imgs = {}
    for k, keys in want.items():
        for key in keys:
            if key in files and "2k" in files[key]:
                fmt = files[key]["2k"].get("jpg") or files[key]["2k"].get("png")
                imgs[k] = Image.open(io.BytesIO(fetch(fmt["url"])))
                break
    if not {"albedo", "normal", "roughness"} <= set(imgs):
        raise RuntimeError("eksik harita: %s" % sorted(imgs))
    if "ao" not in imgs:
        g = np.asarray(to_2k(imgs["albedo"], "L"), dtype=np.float32) / 255.0
        imgs["ao"] = u8(cavity_ao(g, 16, 0.5))
    write_set(name, imgs["albedo"], imgs["normal"], imgs["roughness"], imgs["ao"], imgs.get("metallic"),
              "Poly Haven %s (CC0)" % aid)


def from_ambientcg(name, aid):
    z = zipfile.ZipFile(io.BytesIO(fetch("https://ambientcg.com/get?file=%s_2K-JPG.zip" % aid, 300)))
    def pick(tag):
        for n in z.namelist():
            if n.endswith("_%s.jpg" % tag) or n.endswith("_%s.png" % tag):
                return Image.open(io.BytesIO(z.read(n)))
        return None
    alb, nrm, rgh = pick("Color"), pick("NormalGL"), pick("Roughness")
    if alb is None or nrm is None or rgh is None:
        raise RuntimeError("eksik harita: " + ",".join(z.namelist()))
    ao = pick("AmbientOcclusion")
    if ao is None:
        disp = pick("Displacement")
        src = disp if disp is not None else alb
        ao = u8(cavity_ao(np.asarray(to_2k(src, "L"), dtype=np.float32) / 255.0, 16, 0.8))
    write_set(name, alb, nrm, rgh, ao, pick("Metalness"), "ambientCG %s (CC0)" % aid)


def hdri(name, aid):
    os.makedirs(HDRI, exist_ok=True)
    out = os.path.join(HDRI, name + ".exr")
    files = json.loads(fetch("https://api.polyhaven.com/files/" + aid))
    data = fetch(files["hdri"]["2k"]["exr"]["url"], 300)
    with open(out, "wb") as f:
        f.write(data)
    report["hdri"][name] = {"source": "Poly Haven %s (CC0)" % aid, "bytes": len(data)}
    print("  %-22s Poly Haven %s · %.1f MB" % (name, aid, len(data) / 1e6))


def hdri_fallback(name, warm):
    """Ağ yoksa: yumuşak kutu ışıklı stüdyo panoraması (Radiance .hdr yerine 16 bit PNG → Godot HDR değil)."""
    w, h = 2048, 1024
    v = np.linspace(0, 1, h)[:, None]
    u = np.linspace(0, 1, w)[None, :]
    base = (0.10 + 0.5 * np.clip(0.55 - v, 0, 1)) * np.ones_like(u)
    for cu, cv, s in ((0.25, 0.25, 0.06), (0.62, 0.22, 0.05), (0.9, 0.35, 0.04)):
        base += 6.0 * np.exp(-(((u - cu) / s) ** 2 + ((v - cv) / (s * 0.6)) ** 2))
    col = np.array([1.0, 0.86, 0.7]) if warm else np.array([0.95, 0.97, 1.0])
    img = (np.clip(base[..., None] * col / 6.0, 0, 1) * 65535).astype(np.uint16)
    os.makedirs(HDRI, exist_ok=True)
    Image.fromarray(img[..., 0]).save(os.path.join(HDRI, name + "_fallback.png"))
    report["hdri"][name] = {"source": "procedural fallback"}


def main():
    print("2K PBR kütüphanesi →", PBR)
    for name, kind, aid, fb in SETS:
        try:
            if OFFLINE:
                raise RuntimeError("çevrimdışı")
            (from_polyhaven if kind == "ph" else from_ambientcg)(name, aid)
        except Exception as e:                     # ağ/API sorunu: prosedürel yedek
            print("  %-22s indirilemedi (%s) → prosedürel" % (name, str(e)[:60]))
            procedural(name, fb)
    pcb_circuit()
    gold_contacts()
    print("2K HDRI →", HDRI)
    for name, aid in HDRIS:
        try:
            if OFFLINE:
                raise RuntimeError("çevrimdışı")
            hdri(name, aid)
        except Exception as e:
            print("  %-22s indirilemedi (%s) → prosedürel" % (name, str(e)[:60]))
            hdri_fallback(name, "warm" in name)
    with open(os.path.join(ROOT, "tools", "pbr_2k_report.json"), "w") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
