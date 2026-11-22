# 100 bilgisayar parçasının montaj düzeni (tek kaynak). Çalıştırınca:
#  1) her parçanın sınır kutusunu (AABB) diğerleriyle karşılaştırır — iç içe geçen hacim olmamalı (temas serbest)
#  2) godot-program/scripts/pc/pc_part_library.gd dosyasını üretir.
# Koordinatlar: y yukarı; masa yüzeyi y=0. Kasa solda (x -3.2..1.8), monitör ve klavye sağda.
# Her satır: (ad, şekil, (x0, x1), (y0, y1), (z0, z1), renk)
import itertools, os, sys

MB = 0.36  # anakart üst yüzü
P = [
 # --- Faz 1: Anakart (PCB) & Bakır Yollar ---
 ("Anakart PCB katmanı", "pcb_board", (-1.6, 1.6), (0.30, MB), (-1.5, 1.5), "#0b3b2a"),
 ("Ön-sol montaj direği", "standoff", (-1.51, -1.39), (0.10, 0.30), (1.29, 1.41), "#d4af37"),
 ("Ön-sağ montaj direği", "standoff", (1.39, 1.51), (0.10, 0.30), (1.29, 1.41), "#d4af37"),
 ("Arka-sol montaj direği", "standoff", (-1.51, -1.39), (0.10, 0.30), (-1.41, -1.29), "#d4af37"),
 ("Arka-sağ montaj direği", "standoff", (1.39, 1.51), (0.10, 0.30), (-1.41, -1.29), "#d4af37"),
 ("Bakır güç düzlemi", "trace", (-1.4, 0.9), (MB, 0.368), (1.32, 1.36), "#c27a3e"),
 ("Yonga seti (PCH)", "chip", (0.3, 0.8), (MB, 0.42), (0.8, 1.2), "#1a1a20"),
 ("BIOS flaş yongası", "chip", (1.15, 1.35), (MB, 0.40), (0.65, 0.8), "#202028"),
 ("CMOS pili", "battery", (1.08, 1.32), (MB, 0.40), (1.08, 1.32), "#c9ccd2"),
 ("Ön panel bağlantı pinleri", "header", (0.0, 0.9), (MB, 0.42), (1.38, 1.48), "#1d1f26"),
 # --- Faz 2: Güç Kaynağı (PSU) & Voltaj Regülatörleri ---
 ("Güç kaynağı gövdesi (PSU)", "psu", (-3.1, -1.7), (0.10, 0.90), (-1.6, 0.4), "#26282e"),
 ("PSU fan ızgarası", "grille_y", (-2.9, -1.9), (0.90, 0.94), (-1.2, -0.2), "#9aa0a8"),
 ("Modüler kablo paneli", "panel_conn", (-1.7, -1.66), (0.2, 0.8), (-0.5, 0.2), "#121318"),
 ("AC giriş soketi", "port", (-3.16, -3.1), (0.3, 0.5), (-1.2, -0.9), "#101114"),
 ("Güç bobinleri (choke dizisi)", "choke_row", (-0.9, -0.1), (MB, 0.50), (-1.2, -0.95), "#3a3d44"),
 ("24-pin kablo (ön hat)", "cable_x", (-1.7, 1.6), (0.10, 0.18), (1.55, 1.65), "#161616"),
 ("24-pin kablo (sağ hat)", "cable_z", (1.62, 1.72), (0.10, 0.18), (-0.6, 1.55), "#161616"),
 ("24-pin kablo yükselticisi", "cable_y", (1.62, 1.72), (0.18, 0.62), (-0.7, -0.5), "#161616"),
 ("ATX 24-pin güç soketi", "connector", (1.3, 1.58), (MB, 0.62), (-0.8, -0.4), "#f2f2f2"),
 ("+12V voltaj regülatörü (VRM)", "mosfet_row", (-1.25, -1.0), (MB, 0.42), (-1.0, 0.0), "#1a1a20"),
 # --- Faz 3: İşlemci (CPU) & Soket Mimarisi ---
 ("LGA soket tabanı", "socket", (-0.85, -0.15), (MB, 0.40), (-0.8, -0.1), "#2a2c33"),
 ("Soket pin matrisi", "pins", (-0.8, -0.2), (0.40, 0.42), (-0.75, -0.15), "#d4af37"),
 ("Soket kilit kolu", "lever", (-0.93, -0.87), (MB, 0.44), (-0.8, -0.1), "#c9ccd2"),
 ("İşlemci alt taşı", "substrate", (-0.78, -0.22), (0.42, 0.45), (-0.73, -0.17), "#1f6b3a"),
 ("Çekirdek kalıbı", "die", (-0.65, -0.35), (0.45, 0.47), (-0.6, -0.3), "#5a6ad6"),
 ("Isı dağıtıcı kapak (IHS)", "ihs", (-0.75, -0.25), (0.47, 0.53), (-0.7, -0.2), "#c6cbd3"),
 ("Termal macun", "paste", (-0.66, -0.34), (0.53, 0.54), (-0.61, -0.29), "#9da4ad"),
 ("Soket arka plakası", "backplate", (-0.85, -0.15), (0.22, 0.30), (-0.8, -0.1), "#2a2c33"),
 ("EPS 8-pin işlemci güç soketi", "connector", (-1.58, -1.3), (MB, 0.56), (-1.2, -0.95), "#f2f2f2"),
 ("Saat kristali", "crystal", (-0.1, 0.02), (MB, 0.40), (-0.08, 0.0), "#c9ccd2"),
 # --- Faz 4: RAM Modülleri & Veri Yolları ---
 ("DIMM yuvası A1", "dimm_slot", (0.145, 0.215), (MB, 0.44), (-1.2, 0.0), "#202028"),
 ("DIMM yuvası A2", "dimm_slot", (0.305, 0.375), (MB, 0.44), (-1.2, 0.0), "#3a3d44"),
 ("DIMM yuvası B1", "dimm_slot", (0.465, 0.535), (MB, 0.44), (-1.2, 0.0), "#202028"),
 ("DIMM yuvası B2", "dimm_slot", (0.625, 0.695), (MB, 0.44), (-1.2, 0.0), "#3a3d44"),
 ("DDR5 bellek modülü 1", "dimm", (0.16, 0.20), (0.44, 1.10), (-1.15, -0.05), "#1f6b3a"),
 ("DDR5 bellek modülü 2", "dimm", (0.32, 0.36), (0.44, 1.10), (-1.15, -0.05), "#1f6b3a"),
 ("DDR5 bellek modülü 3", "dimm", (0.48, 0.52), (0.44, 1.10), (-1.15, -0.05), "#1f6b3a"),
 ("DDR5 bellek modülü 4", "dimm", (0.64, 0.68), (0.44, 1.10), (-1.15, -0.05), "#1f6b3a"),
 ("DIMM kilit klipsleri", "clip", (0.12, 0.70), (MB, 0.50), (-1.28, -1.2), "#e8e8ee"),
 ("RGB bellek ışık çubuğu", "rgb_bar", (0.12, 0.70), (1.10, 1.16), (-1.15, -0.05), "#8a5cff"),
 # --- Faz 5: Depolama (NVMe SSD) ---
 ("M.2 yuvası 1", "m2_slot", (-0.42, -0.3), (MB, 0.42), (0.8, 1.0), "#202028"),
 ("NVMe SSD 1 kartı", "ssd", (-1.4, -0.42), (0.38, 0.40), (0.82, 0.98), "#0f3f2c"),
 ("NAND flaş yongaları", "chip_flat", (-1.3, -0.95), (0.40, 0.43), (0.84, 0.96), "#16161b"),
 ("SSD denetleyicisi", "chip_flat", (-0.85, -0.65), (0.40, 0.43), (0.84, 0.96), "#1d1f26"),
 ("DRAM önbellek yongası", "chip_flat", (-0.6, -0.5), (0.40, 0.43), (0.85, 0.95), "#16161b"),
 ("M.2 ısı emicisi 1", "heatsink", (-1.4, -0.45), (0.43, 0.50), (0.8, 1.0), "#4a4f58"),
 ("M.2 yuvası 2", "m2_slot", (-0.42, -0.3), (MB, 0.42), (1.1, 1.3), "#202028"),
 ("NVMe SSD 2 kartı", "ssd", (-1.4, -0.42), (0.38, 0.40), (1.12, 1.28), "#0f3f2c"),
 ("M.2 ısı emicisi 2", "heatsink", (-1.4, -0.45), (0.40, 0.48), (1.1, 1.3), "#4a4f58"),
 ("M.2 sabitleme vidası", "screw", (-1.49, -1.43), (MB, 0.42), (0.86, 0.94), "#c9ccd2"),
 # --- Faz 6: Ekran Kartı (GPU) & VRAM ---
 ("PCIe x16 yuvası", "pcie_slot", (-1.3, 0.3), (MB, 0.44), (0.25, 0.35), "#202028"),
 ("GPU baskı devre kartı", "gpu_pcb", (-1.55, 0.95), (0.44, 1.50), (0.26, 0.30), "#0b3b2a"),
 ("GPU arka plakası", "backplate_v", (-1.55, 0.95), (0.46, 1.50), (0.20, 0.26), "#2c2f36"),
 ("GDDR6 VRAM yongaları", "vram", (-1.2, 0.4), (0.70, 1.20), (0.16, 0.20), "#16161b"),
 ("GPU çekirdeği", "die_v", (-0.5, -0.1), (0.80, 1.20), (0.30, 0.33), "#5a6ad6"),
 ("GPU ısı emici kanatları", "fins_z", (-1.5, 0.9), (0.46, 1.48), (0.33, 0.50), "#9aa0a8"),
 ("GPU kaplaması", "shroud", (-1.55, 0.95), (0.44, 1.50), (0.50, 0.62), "#30333b"),
 ("GPU fanı 1", "fan_z", (-1.33, -0.67), (0.64, 1.30), (0.62, 0.66), "#18191e"),
 ("GPU fanı 2", "fan_z", (-0.33, 0.33), (0.64, 1.30), (0.62, 0.66), "#18191e"),
 ("12VHPWR GPU güç soketi", "connector", (0.5, 0.8), (1.50, 1.60), (0.26, 0.36), "#16161b"),
 # --- Faz 7: Soğutma Sistemi ---
 ("İşlemci soğutucu taban plakası", "coldplate", (-0.75, -0.25), (0.54, 0.60), (-0.7, -0.2), "#c27a3e"),
 ("Isı boruları", "heatpipes", (-0.72, -0.28), (0.60, 0.75), (-0.65, -0.25), "#c27a3e"),
 ("Alüminyum kanat yığını", "fins_y", (-0.85, -0.15), (0.75, 1.65), (-0.8, -0.1), "#b8bec7"),
 ("İşlemci fanı", "fan_x", (-0.13, -0.03), (0.80, 1.60), (-0.8, -0.1), "#18191e"),
 ("VRM soğutucusu", "heatsink", (-1.25, -1.0), (0.42, 0.80), (-1.0, 0.0), "#4a4f58"),
 ("Yonga seti soğutucusu", "heatsink", (0.3, 0.8), (0.42, 0.52), (0.8, 1.2), "#4a4f58"),
 ("Arka kasa fanı", "fan_z", (-1.2, 0.0), (1.80, 3.00), (-1.7, -1.55), "#18191e"),
 ("Üst kasa fanı 1", "fan_y", (-2.4, -1.2), (3.75, 3.90), (-0.6, 0.6), "#18191e"),
 ("Üst kasa fanı 2", "fan_y", (-0.9, 0.3), (3.75, 3.90), (-0.6, 0.6), "#18191e"),
 ("Fan kontrol merkezi", "chip", (1.3, 1.6), (MB, 0.45), (-1.4, -1.1), "#1d1f26"),
 # --- Faz 8: Ses, Ağ ve I/O Portları ---
 ("Arka I/O kalkanı", "io_shield", (-1.6, -0.3), (0.30, 0.80), (-1.56, -1.5), "#9aa0a8"),
 ("USB 3.2 port bloğu", "usb", (-1.55, -1.3), (MB, 0.62), (-1.48, -1.28), "#2a2c33"),
 ("USB-C portu", "port", (-1.25, -1.1), (MB, 0.50), (-1.48, -1.3), "#c9ccd2"),
 ("2.5G Ethernet portu", "port", (-1.05, -0.85), (MB, 0.66), (-1.48, -1.28), "#2a2c33"),
 ("Wi-Fi anten konnektörleri", "port", (-0.8, -0.65), (MB, 0.56), (-1.48, -1.3), "#d4af37"),
 ("HDMI / DisplayPort çıkışları", "port", (-0.6, -0.45), (MB, 0.60), (-1.48, -1.28), "#2a2c33"),
 ("Ses jakları", "jacks", (-0.42, -0.31), (MB, 0.70), (-1.48, -1.3), "#3cc07a"),
 ("Ses kodek yongası", "chip", (-1.55, -1.35), (MB, 0.40), (0.4, 0.7), "#1d1f26"),
 ("Wi-Fi antenleri", "antenna", (-1.0, -0.6), (0.50, 1.30), (-1.95, -1.85), "#18191e"),
 ("Ağ denetleyici yongası", "chip", (-0.25, -0.05), (MB, 0.39), (-1.45, -1.3), "#1d1f26"),
 # --- Faz 9: Kasa, Kablolama ve Aydınlatma ---
 ("Kasa taban tepsisi", "tray", (-3.2, 1.8), (0.0, 0.10), (-1.8, 1.8), "#2a2d34"),
 ("Kasa arka paneli", "panel_v", (-3.2, 1.8), (0.10, 4.00), (-1.8, -1.7), "#30333b"),
 ("Sol ön kasa direği", "pillar", (-3.2, -3.05), (0.10, 4.00), (1.65, 1.8), "#30333b"),
 ("Sağ ön kasa direği", "pillar", (1.65, 1.8), (0.10, 4.00), (1.65, 1.8), "#30333b"),
 ("Üst kasa çerçevesi", "frame_top", (-3.2, 1.8), (4.00, 4.08), (-1.7, 1.8), "#30333b"),
 ("Temperli cam ön panel", "glass", (-3.05, 1.65), (0.10, 4.00), (1.8, 1.83), "#bfe4ff"),
 ("RGB LED şerit", "led_strip", (-3.0, 1.6), (3.92, 3.97), (1.5, 1.6), "#8a5cff"),
 ("EPS kablo yükselticisi", "cable_y", (-1.68, -1.6), (0.20, 0.90), (-1.15, -1.0), "#161616"),
 ("Ön panel kablo demeti", "cable_x", (0.0, 0.9), (MB, 0.40), (1.5, 1.54), "#3a3d44"),
 ("Güç düğmesi", "button", (1.2, 1.4), (4.08, 4.14), (1.2, 1.4), "#c9ccd2"),
 # --- Faz 10: Monitör, Klavye ve Sistem Çekirdeği ---
 ("Monitör ayağı tabanı", "mon_base", (3.2, 4.4), (0.0, 0.06), (-1.6, -0.8), "#2a2c33"),
 ("Monitör boynu", "neck", (3.7, 3.9), (0.06, 1.00), (-1.3, -1.12), "#2a2c33"),
 ("Monitör panel gövdesi", "mon_panel", (2.3, 5.3), (1.00, 2.90), (-1.12, -0.95), "#1d1f26"),
 ("IPS ekran katmanı", "screen", (2.4, 5.2), (1.10, 2.80), (-0.95, -0.93), "#3aa8ff"),
 ("Klavye gövdesi", "kb_base", (2.6, 5.0), (0.0, 0.10), (0.6, 1.5), "#24262c"),
 ("Mekanik tuş takımı", "keys", (2.65, 4.95), (0.10, 0.17), (0.65, 1.45), "#e8e8ee"),
 ("Fare", "mouse", (5.4, 5.7), (0.02, 0.14), (0.9, 1.3), "#24262c"),
 ("Fare altlığı", "pad", (5.2, 5.9), (0.0, 0.02), (0.6, 1.6), "#30333b"),
 ("Masaüstü hoparlör", "speaker", (5.5, 6.0), (0.0, 0.90), (-1.3, -0.8), "#24262c"),
 ("Sistem çekirdeği", "core", (-1.0, -0.4), (4.50, 5.10), (-0.3, 0.3), "#62f2ff"),
]
PHASES = ["Anakart (PCB) & Bakır Yollar", "Güç Kaynağı (PSU) & Voltaj Regülatörleri", "İşlemci (CPU) & Soket Mimarisi",
          "RAM Modülleri & Veri Yolları", "Depolama (NVMe SSD)", "Ekran Kartı (GPU) & VRAM", "Soğutma Sistemi (Fanlar, Isı Boruları)",
          "Ses, Ağ ve I/O Portları", "Kasa, Kablolama ve Aydınlatma", "Monitör, Klavye ve Sistem Çekirdeği"]

def check():
    assert len(P) == 100, len(P)
    names = [p[0] for p in P]
    assert len(set(names)) == 100, "aynı ad"
    bad = []
    for (i, a), (j, b) in itertools.combinations(enumerate(P), 2):
        ov = 1.0
        for k in (2, 3, 4):
            lo = max(a[k][0], b[k][0]); hi = min(a[k][1], b[k][1])
            ov *= max(0.0, hi - lo - 1e-6)
        if ov > 1e-7:
            bad.append((i + 1, a[0], j + 1, b[0], ov))
    for (i, a) in enumerate(P):
        for k in (2, 3, 4):
            assert a[k][1] > a[k][0], (a[0], k)
    return bad

def emit(path):
    rows = []
    for i, (name, shape, xs, ys, zs, col) in enumerate(P):
        c = ((xs[0] + xs[1]) / 2, (ys[0] + ys[1]) / 2, (zs[0] + zs[1]) / 2)
        s = (xs[1] - xs[0], ys[1] - ys[0], zs[1] - zs[0])
        rows.append('\t["%s", "%s", Vector3(%.4f, %.4f, %.4f), Vector3(%.4f, %.4f, %.4f), "%s"],' % (name, shape, *c, *s, col))
    src = open(os.path.join(os.path.dirname(__file__), 'pc_part_library.gd.in')).read()
    out = src.replace('%ROWS%', '\n'.join(rows)).replace('%PHASES%', ', '.join('"%s"' % p for p in PHASES))
    open(path, 'w').write(out)

if __name__ == '__main__':
    bad = check()
    for b in bad: print('ÇAKIŞMA #%d %s <-> #%d %s (hacim %.5f)' % b)
    print('parça:', len(P), 'çakışma:', len(bad))
    if bad: sys.exit(1)
    if len(sys.argv) > 1: emit(sys.argv[1])
