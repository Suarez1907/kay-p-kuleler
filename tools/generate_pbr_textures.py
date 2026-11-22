#!/usr/bin/env python3
"""Kayıp Kuleler — döşenebilir PBR doku setleri (numpy + Pillow).

    python3 tools/generate_pbr_textures.py

Çıktı: godot-program/assets/textures/pbr/<malzeme>/{albedo,normal,roughness}.png (1024², döşenebilir)
Malzemeler: brushed_aluminum, copper, gold, epoxy, black_plastic, dark_metal, ceramic, rubber, glass_frost.
Godot'da AssetLoader.enhance_materials() glTF malzemelerini adına göre bu setlere (triplanar) bağlar.
Döşenebilirlik: bütün gürültüler periyodik (FFT tabanlı) üretilir; normal haritası sarmalı türevle çıkarılır.
"""
import os
import numpy as np
from PIL import Image

N = 1024
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "godot-program", "assets", "textures", "pbr"))
rng = np.random.default_rng(77)

def fft_noise(beta=2.0, aniso=(1.0, 1.0), seed=None):
    """Periyodik 1/f^beta gürültü, 0..1. aniso: (x, y) frekans ölçeği (fırçalanmış metal için uzatılmış)."""
    r = np.random.default_rng(seed) if seed is not None else rng
    w = r.standard_normal((N, N)) + 1j * r.standard_normal((N, N))
    fx = np.fft.fftfreq(N)[None, :] * aniso[0]
    fy = np.fft.fftfreq(N)[:, None] * aniso[1]
    f = np.sqrt(fx ** 2 + fy ** 2)
    f[0, 0] = 1.0
    img = np.real(np.fft.ifft2(w / f ** (beta / 2)))
    img -= img.min()
    return img / (img.max() + 1e-9)

def normal_from_height(h, strength=4.0):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.dstack([-dx, dy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5

def srgb(hexs):
    h = hexs.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])

def save(name, albedo, normal, rough):
    d = os.path.join(ROOT, name)
    os.makedirs(d, exist_ok=True)
    Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8)).save(os.path.join(d, "albedo.png"), optimize=True)
    Image.fromarray((np.clip(normal, 0, 1) * 255).astype(np.uint8)).save(os.path.join(d, "normal.png"), optimize=True)
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8)).save(os.path.join(d, "roughness.png"), optimize=True)
    print("  %-18s ok" % name)

def tint(base_hex, var, amount):
    b = srgb(base_hex)
    return np.clip(b[None, None, :] * (1 - amount + amount * 2 * var[..., None]), 0, 1)

def main():
    print("PBR doku setleri →", ROOT)
    # fırçalanmış alüminyum: x yönünde çok uzun çizgiler
    br = fft_noise(1.2, (1.0, 60.0), 1)
    fine = fft_noise(0.6, (1, 1), 2)
    h = br * 0.8 + fine * 0.2
    save("brushed_aluminum", tint("#b8bec7", h, 0.12), normal_from_height(h, 2.0), 0.28 + 0.18 * h)
    # bakır: oksit lekeleri + ince çizik
    patina = fft_noise(3.0, (1, 1), 3)
    scratch = fft_noise(1.0, (1.0, 25.0), 4)
    alb = tint("#c87533", patina, 0.18)
    spots = np.clip((patina - 0.72) * 4, 0, 1)[..., None]
    alb = alb * (1 - spots * 0.45) + srgb("#4f8a6a")[None, None, :] * spots * 0.45
    hh = patina * 0.6 + scratch * 0.4
    save("copper", alb, normal_from_height(hh, 2.5), 0.24 + 0.3 * patina)
    # altın: çok hafif dalgalı, parlak
    g = fft_noise(2.5, (1, 1), 5)
    save("gold", tint("#d4af37", g, 0.08), normal_from_height(g, 1.2), 0.18 + 0.12 * g)
    # epoksi (çip gövdesi): mat, mikro dokulu, ince kalıp işaretleri
    e = fft_noise(0.3, (1, 1), 6)
    big = fft_noise(3.0, (1, 1), 7)
    save("epoxy", tint("#1a1c20", big, 0.25), normal_from_height(e * 0.4, 6.0), 0.66 + 0.12 * e)
    # siyah plastik: hafif dokulu (kalıp kumlaması)
    p = fft_noise(0.2, (1, 1), 8)
    save("black_plastic", tint("#202128", p, 0.12), normal_from_height(p * 0.5, 5.0), 0.55 + 0.15 * p)
    # koyu metal: anodize, ince çizikler
    dm = fft_noise(1.0, (1.0, 18.0), 9) * 0.5 + fft_noise(2.5, (1, 1), 10) * 0.5
    save("dark_metal", tint("#30333b", dm, 0.15), normal_from_height(dm, 2.0), 0.32 + 0.2 * dm)
    # seramik (direnç gövdesi): hafif benekli
    c = fft_noise(1.6, (1, 1), 11)
    speck = (rng.random((N, N)) > 0.997).astype(float)
    save("ceramic", tint("#d9c49c", c, 0.1) * (1 - speck[..., None] * 0.4), normal_from_height(c * 0.5, 3.0), 0.7 + 0.15 * c)
    # kauçuk (palet): sık pürüz
    r_ = fft_noise(0.1, (1, 1), 12)
    save("rubber", tint("#1c1d22", r_, 0.1), normal_from_height(r_, 7.0), 0.82 + 0.1 * r_)
    # buzlu cam (vitrin cam paneli kenar pürüzü)
    gf = fft_noise(1.0, (1, 1), 13)
    save("glass_frost", tint("#bfe4ff", gf, 0.05), normal_from_height(gf * 0.3, 2.0), 0.05 + 0.1 * gf)

if __name__ == "__main__":
    main()
