#!/usr/bin/env python3
"""Godot içe aktarma ayarlarını mobil VRAM ve LightmapGI kurallarına göre yazar.

    python3 tools/configure_pbr_imports.py          # sonra: godot --headless --path godot-program --import

* assets/textures/pbr/*_2k/*.jpg|png  → compress/mode=2 (VRAM: Android'de ASTC/ETC2), mipmaps/generate=true,
  detect_3d/compress_to=1; normal haritaları compress/normal_map=1 (RG kanal sıkıştırma)
* assets/hdri/*.exr                   → kayıpsız (gökyüzü radyans haritası çalışma anında üretilir), mipmap yok
* statik .glb modelleri               → meshes/light_baking=2 (Static: GI_MODE_STATIC, Blender'daki UV2 kullanılır),
  lightmap_texel_size=0.05 (küçük devre elemanları için ince ışık haritası)
Değişen her dosyanın .godot/imported önbelleği silinir; Godot bir sonraki --import'ta yeniden içe aktarır.
"""
import glob
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "godot-program"))
STATIC_GLB = ["assets/models/components/*.glb", "assets/models/pc_parts/*.glb", "assets/models/backdrops/*.glb",
              "assets/models/puzzle/stairs.glb", "assets/models/scenes/*.glb"]


def setp(text, key, val):
    pat = re.compile(r"(?m)^%s=.*$" % re.escape(key))
    if pat.search(text):
        return pat.sub("%s=%s" % (key, val), text)
    return text.rstrip("\n") + "\n%s=%s\n" % (key, val)


def drop_cache(text):
    for p in re.findall(r'"res://(\.godot/imported/[^"]+)"', text):
        for f in glob.glob(os.path.join(ROOT, p.rsplit(".", 1)[0] + ".*")):
            os.remove(f)


def patch(path, params):
    s = open(path).read()
    t = s
    for k, v in params.items():
        t = setp(t, k, v)
    if t != s:
        drop_cache(s)
        open(path, "w").write(t)
        return True
    return False


def main():
    n_tex = n_hdr = n_glb = 0
    for imp in glob.glob(os.path.join(ROOT, "assets/textures/pbr/*_2k/*.import")):
        p = {"compress/mode": "2", "mipmaps/generate": "true", "detect_3d/compress_to": "1",
             "compress/high_quality": "false"}
        p["compress/normal_map"] = "1" if "normal" in os.path.basename(imp) or "nor_gl" in imp else "0"
        n_tex += patch(imp, p)
    for imp in glob.glob(os.path.join(ROOT, "assets/hdri/*.exr.import")):
        n_hdr += patch(imp, {"compress/mode": "0", "mipmaps/generate": "false", "detect_3d/compress_to": "0"})
    for pat in STATIC_GLB:
        for imp in glob.glob(os.path.join(ROOT, pat + ".import")):
            n_glb += patch(imp, {"meshes/light_baking": "2", "meshes/lightmap_texel_size": "0.05"})
    print("içe aktarma ayarları: %d doku, %d HDRI, %d statik model güncellendi" % (n_tex, n_hdr, n_glb))


if __name__ == "__main__":
    main()
