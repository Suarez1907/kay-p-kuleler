## 100 parçalık bilgisayar donanım kütüphanesi. OTOMATİK ÜRETİLDİ: tools/pc_parts.py (düzen ve çakışma
## denetimi oradadır; elle düzenlemeyin). Parça N, N. seviye ilk kez tamamlanınca kazanılır.
## Montaj düzeni: masa (y=0) üstünde açık kasa; taban tepsisi → montaj direkleri → yatay anakart →
## üstünde işlemci, RAM, M.2 SSD'ler ve dik duran ekran kartı → çevresinde PSU, fanlar, kasa çerçevesi →
## sağda monitör, klavye, fare, hoparlör; en üstte sistem çekirdeği.
class_name PCPartLibrary
extends RefCounted

const COUNT := 100
const PER_PHASE := 10
const PHASES := ["Anakart (PCB) & Bakır Yollar", "Güç Kaynağı (PSU) & Voltaj Regülatörleri", "İşlemci (CPU) & Soket Mimarisi", "RAM Modülleri & Veri Yolları", "Depolama (NVMe SSD)", "Ekran Kartı (GPU) & VRAM", "Soğutma Sistemi (Fanlar, Isı Boruları)", "Ses, Ağ ve I/O Portları", "Kasa, Kablolama ve Aydınlatma", "Monitör, Klavye ve Sistem Çekirdeği"]
## ad, prosedürel şekil, montaj merkezi, sınır kutusu boyutu, renk
const ROWS := [
	["Anakart PCB katmanı", "pcb_board", Vector3(0.0000, 0.3300, 0.0000), Vector3(3.2000, 0.0600, 3.0000), "#0b3b2a"],
	["Ön-sol montaj direği", "standoff", Vector3(-1.4500, 0.2000, 1.3500), Vector3(0.1200, 0.2000, 0.1200), "#d4af37"],
	["Ön-sağ montaj direği", "standoff", Vector3(1.4500, 0.2000, 1.3500), Vector3(0.1200, 0.2000, 0.1200), "#d4af37"],
	["Arka-sol montaj direği", "standoff", Vector3(-1.4500, 0.2000, -1.3500), Vector3(0.1200, 0.2000, 0.1200), "#d4af37"],
	["Arka-sağ montaj direği", "standoff", Vector3(1.4500, 0.2000, -1.3500), Vector3(0.1200, 0.2000, 0.1200), "#d4af37"],
	["Bakır güç düzlemi", "trace", Vector3(-0.2500, 0.3640, 1.3400), Vector3(2.3000, 0.0080, 0.0400), "#c27a3e"],
	["Yonga seti (PCH)", "chip", Vector3(0.5500, 0.3900, 1.0000), Vector3(0.5000, 0.0600, 0.4000), "#1a1a20"],
	["BIOS flaş yongası", "chip", Vector3(1.2500, 0.3800, 0.7250), Vector3(0.2000, 0.0400, 0.1500), "#202028"],
	["CMOS pili", "battery", Vector3(1.2000, 0.3800, 1.2000), Vector3(0.2400, 0.0400, 0.2400), "#c9ccd2"],
	["Ön panel bağlantı pinleri", "header", Vector3(0.4500, 0.3900, 1.4300), Vector3(0.9000, 0.0600, 0.1000), "#1d1f26"],
	["Güç kaynağı gövdesi (PSU)", "psu", Vector3(-2.4000, 0.5000, -0.6000), Vector3(1.4000, 0.8000, 2.0000), "#26282e"],
	["PSU fan ızgarası", "grille_y", Vector3(-2.4000, 0.9200, -0.7000), Vector3(1.0000, 0.0400, 1.0000), "#9aa0a8"],
	["Modüler kablo paneli", "panel_conn", Vector3(-1.6800, 0.5000, -0.1500), Vector3(0.0400, 0.6000, 0.7000), "#121318"],
	["AC giriş soketi", "port", Vector3(-3.1300, 0.4000, -1.0500), Vector3(0.0600, 0.2000, 0.3000), "#101114"],
	["Güç bobinleri (choke dizisi)", "choke_row", Vector3(-0.5000, 0.4300, -1.0750), Vector3(0.8000, 0.1400, 0.2500), "#3a3d44"],
	["24-pin kablo (ön hat)", "cable_x", Vector3(-0.0500, 0.1400, 1.6000), Vector3(3.3000, 0.0800, 0.1000), "#161616"],
	["24-pin kablo (sağ hat)", "cable_z", Vector3(1.6700, 0.1400, 0.4750), Vector3(0.1000, 0.0800, 2.1500), "#161616"],
	["24-pin kablo yükselticisi", "cable_y", Vector3(1.6700, 0.4000, -0.6000), Vector3(0.1000, 0.4400, 0.2000), "#161616"],
	["ATX 24-pin güç soketi", "connector", Vector3(1.4400, 0.4900, -0.6000), Vector3(0.2800, 0.2600, 0.4000), "#f2f2f2"],
	["+12V voltaj regülatörü (VRM)", "mosfet_row", Vector3(-1.1250, 0.3900, -0.5000), Vector3(0.2500, 0.0600, 1.0000), "#1a1a20"],
	["LGA soket tabanı", "socket", Vector3(-0.5000, 0.3800, -0.4500), Vector3(0.7000, 0.0400, 0.7000), "#2a2c33"],
	["Soket pin matrisi", "pins", Vector3(-0.5000, 0.4100, -0.4500), Vector3(0.6000, 0.0200, 0.6000), "#d4af37"],
	["Soket kilit kolu", "lever", Vector3(-0.9000, 0.4000, -0.4500), Vector3(0.0600, 0.0800, 0.7000), "#c9ccd2"],
	["İşlemci alt taşı", "substrate", Vector3(-0.5000, 0.4350, -0.4500), Vector3(0.5600, 0.0300, 0.5600), "#1f6b3a"],
	["Çekirdek kalıbı", "die", Vector3(-0.5000, 0.4600, -0.4500), Vector3(0.3000, 0.0200, 0.3000), "#5a6ad6"],
	["Isı dağıtıcı kapak (IHS)", "ihs", Vector3(-0.5000, 0.5000, -0.4500), Vector3(0.5000, 0.0600, 0.5000), "#c6cbd3"],
	["Termal macun", "paste", Vector3(-0.5000, 0.5350, -0.4500), Vector3(0.3200, 0.0100, 0.3200), "#9da4ad"],
	["Soket arka plakası", "backplate", Vector3(-0.5000, 0.2600, -0.4500), Vector3(0.7000, 0.0800, 0.7000), "#2a2c33"],
	["EPS 8-pin işlemci güç soketi", "connector", Vector3(-1.4400, 0.4600, -1.0750), Vector3(0.2800, 0.2000, 0.2500), "#f2f2f2"],
	["Saat kristali", "crystal", Vector3(-0.0400, 0.3800, -0.0400), Vector3(0.1200, 0.0400, 0.0800), "#c9ccd2"],
	["DIMM yuvası A1", "dimm_slot", Vector3(0.1800, 0.4000, -0.6000), Vector3(0.0700, 0.0800, 1.2000), "#202028"],
	["DIMM yuvası A2", "dimm_slot", Vector3(0.3400, 0.4000, -0.6000), Vector3(0.0700, 0.0800, 1.2000), "#3a3d44"],
	["DIMM yuvası B1", "dimm_slot", Vector3(0.5000, 0.4000, -0.6000), Vector3(0.0700, 0.0800, 1.2000), "#202028"],
	["DIMM yuvası B2", "dimm_slot", Vector3(0.6600, 0.4000, -0.6000), Vector3(0.0700, 0.0800, 1.2000), "#3a3d44"],
	["DDR5 bellek modülü 1", "dimm", Vector3(0.1800, 0.7700, -0.6000), Vector3(0.0400, 0.6600, 1.1000), "#1f6b3a"],
	["DDR5 bellek modülü 2", "dimm", Vector3(0.3400, 0.7700, -0.6000), Vector3(0.0400, 0.6600, 1.1000), "#1f6b3a"],
	["DDR5 bellek modülü 3", "dimm", Vector3(0.5000, 0.7700, -0.6000), Vector3(0.0400, 0.6600, 1.1000), "#1f6b3a"],
	["DDR5 bellek modülü 4", "dimm", Vector3(0.6600, 0.7700, -0.6000), Vector3(0.0400, 0.6600, 1.1000), "#1f6b3a"],
	["DIMM kilit klipsleri", "clip", Vector3(0.4100, 0.4300, -1.2400), Vector3(0.5800, 0.1400, 0.0800), "#e8e8ee"],
	["RGB bellek ışık çubuğu", "rgb_bar", Vector3(0.4100, 1.1300, -0.6000), Vector3(0.5800, 0.0600, 1.1000), "#8a5cff"],
	["M.2 yuvası 1", "m2_slot", Vector3(-0.3600, 0.3900, 0.9000), Vector3(0.1200, 0.0600, 0.2000), "#202028"],
	["NVMe SSD 1 kartı", "ssd", Vector3(-0.9100, 0.3900, 0.9000), Vector3(0.9800, 0.0200, 0.1600), "#0f3f2c"],
	["NAND flaş yongaları", "chip_flat", Vector3(-1.1250, 0.4150, 0.9000), Vector3(0.3500, 0.0300, 0.1200), "#16161b"],
	["SSD denetleyicisi", "chip_flat", Vector3(-0.7500, 0.4150, 0.9000), Vector3(0.2000, 0.0300, 0.1200), "#1d1f26"],
	["DRAM önbellek yongası", "chip_flat", Vector3(-0.5500, 0.4150, 0.9000), Vector3(0.1000, 0.0300, 0.1000), "#16161b"],
	["M.2 ısı emicisi 1", "heatsink", Vector3(-0.9250, 0.4650, 0.9000), Vector3(0.9500, 0.0700, 0.2000), "#4a4f58"],
	["M.2 yuvası 2", "m2_slot", Vector3(-0.3600, 0.3900, 1.2000), Vector3(0.1200, 0.0600, 0.2000), "#202028"],
	["NVMe SSD 2 kartı", "ssd", Vector3(-0.9100, 0.3900, 1.2000), Vector3(0.9800, 0.0200, 0.1600), "#0f3f2c"],
	["M.2 ısı emicisi 2", "heatsink", Vector3(-0.9250, 0.4400, 1.2000), Vector3(0.9500, 0.0800, 0.2000), "#4a4f58"],
	["M.2 sabitleme vidası", "screw", Vector3(-1.4600, 0.3900, 0.9000), Vector3(0.0600, 0.0600, 0.0800), "#c9ccd2"],
	["PCIe x16 yuvası", "pcie_slot", Vector3(-0.5000, 0.4000, 0.3000), Vector3(1.6000, 0.0800, 0.1000), "#202028"],
	["GPU baskı devre kartı", "gpu_pcb", Vector3(-0.3000, 0.9700, 0.2800), Vector3(2.5000, 1.0600, 0.0400), "#0b3b2a"],
	["GPU arka plakası", "backplate_v", Vector3(-0.3000, 0.9800, 0.2300), Vector3(2.5000, 1.0400, 0.0600), "#2c2f36"],
	["GDDR6 VRAM yongaları", "vram", Vector3(-0.4000, 0.9500, 0.1800), Vector3(1.6000, 0.5000, 0.0400), "#16161b"],
	["GPU çekirdeği", "die_v", Vector3(-0.3000, 1.0000, 0.3150), Vector3(0.4000, 0.4000, 0.0300), "#5a6ad6"],
	["GPU ısı emici kanatları", "fins_z", Vector3(-0.3000, 0.9700, 0.4150), Vector3(2.4000, 1.0200, 0.1700), "#9aa0a8"],
	["GPU kaplaması", "shroud", Vector3(-0.3000, 0.9700, 0.5600), Vector3(2.5000, 1.0600, 0.1200), "#30333b"],
	["GPU fanı 1", "fan_z", Vector3(-1.0000, 0.9700, 0.6400), Vector3(0.6600, 0.6600, 0.0400), "#18191e"],
	["GPU fanı 2", "fan_z", Vector3(0.0000, 0.9700, 0.6400), Vector3(0.6600, 0.6600, 0.0400), "#18191e"],
	["12VHPWR GPU güç soketi", "connector", Vector3(0.6500, 1.5500, 0.3100), Vector3(0.3000, 0.1000, 0.1000), "#16161b"],
	["İşlemci soğutucu taban plakası", "coldplate", Vector3(-0.5000, 0.5700, -0.4500), Vector3(0.5000, 0.0600, 0.5000), "#c27a3e"],
	["Isı boruları", "heatpipes", Vector3(-0.5000, 0.6750, -0.4500), Vector3(0.4400, 0.1500, 0.4000), "#c27a3e"],
	["Alüminyum kanat yığını", "fins_y", Vector3(-0.5000, 1.2000, -0.4500), Vector3(0.7000, 0.9000, 0.7000), "#b8bec7"],
	["İşlemci fanı", "fan_x", Vector3(-0.0800, 1.2000, -0.4500), Vector3(0.1000, 0.8000, 0.7000), "#18191e"],
	["VRM soğutucusu", "heatsink", Vector3(-1.1250, 0.6100, -0.5000), Vector3(0.2500, 0.3800, 1.0000), "#4a4f58"],
	["Yonga seti soğutucusu", "heatsink", Vector3(0.5500, 0.4700, 1.0000), Vector3(0.5000, 0.1000, 0.4000), "#4a4f58"],
	["Arka kasa fanı", "fan_z", Vector3(-0.6000, 2.4000, -1.6250), Vector3(1.2000, 1.2000, 0.1500), "#18191e"],
	["Üst kasa fanı 1", "fan_y", Vector3(-1.8000, 3.8250, 0.0000), Vector3(1.2000, 0.1500, 1.2000), "#18191e"],
	["Üst kasa fanı 2", "fan_y", Vector3(-0.3000, 3.8250, 0.0000), Vector3(1.2000, 0.1500, 1.2000), "#18191e"],
	["Fan kontrol merkezi", "chip", Vector3(1.4500, 0.4050, -1.2500), Vector3(0.3000, 0.0900, 0.3000), "#1d1f26"],
	["Arka I/O kalkanı", "io_shield", Vector3(-0.9500, 0.5500, -1.5300), Vector3(1.3000, 0.5000, 0.0600), "#9aa0a8"],
	["USB 3.2 port bloğu", "usb", Vector3(-1.4250, 0.4900, -1.3800), Vector3(0.2500, 0.2600, 0.2000), "#2a2c33"],
	["USB-C portu", "port", Vector3(-1.1750, 0.4300, -1.3900), Vector3(0.1500, 0.1400, 0.1800), "#c9ccd2"],
	["2.5G Ethernet portu", "port", Vector3(-0.9500, 0.5100, -1.3800), Vector3(0.2000, 0.3000, 0.2000), "#2a2c33"],
	["Wi-Fi anten konnektörleri", "port", Vector3(-0.7250, 0.4600, -1.3900), Vector3(0.1500, 0.2000, 0.1800), "#d4af37"],
	["HDMI / DisplayPort çıkışları", "port", Vector3(-0.5250, 0.4800, -1.3800), Vector3(0.1500, 0.2400, 0.2000), "#2a2c33"],
	["Ses jakları", "jacks", Vector3(-0.3650, 0.5300, -1.3900), Vector3(0.1100, 0.3400, 0.1800), "#3cc07a"],
	["Ses kodek yongası", "chip", Vector3(-1.4500, 0.3800, 0.5500), Vector3(0.2000, 0.0400, 0.3000), "#1d1f26"],
	["Wi-Fi antenleri", "antenna", Vector3(-0.8000, 0.9000, -1.9000), Vector3(0.4000, 0.8000, 0.1000), "#18191e"],
	["Ağ denetleyici yongası", "chip", Vector3(-0.1500, 0.3750, -1.3750), Vector3(0.2000, 0.0300, 0.1500), "#1d1f26"],
	["Kasa taban tepsisi", "tray", Vector3(-0.7000, 0.0500, 0.0000), Vector3(5.0000, 0.1000, 3.6000), "#2a2d34"],
	["Kasa arka paneli", "panel_v", Vector3(-0.7000, 2.0500, -1.7500), Vector3(5.0000, 3.9000, 0.1000), "#30333b"],
	["Sol ön kasa direği", "pillar", Vector3(-3.1250, 2.0500, 1.7250), Vector3(0.1500, 3.9000, 0.1500), "#30333b"],
	["Sağ ön kasa direği", "pillar", Vector3(1.7250, 2.0500, 1.7250), Vector3(0.1500, 3.9000, 0.1500), "#30333b"],
	["Üst kasa çerçevesi", "frame_top", Vector3(-0.7000, 4.0400, 0.0500), Vector3(5.0000, 0.0800, 3.5000), "#30333b"],
	["Temperli cam ön panel", "glass", Vector3(-0.7000, 2.0500, 1.8150), Vector3(4.7000, 3.9000, 0.0300), "#bfe4ff"],
	["RGB LED şerit", "led_strip", Vector3(-0.7000, 3.9450, 1.5500), Vector3(4.6000, 0.0500, 0.1000), "#8a5cff"],
	["EPS kablo yükselticisi", "cable_y", Vector3(-1.6400, 0.5500, -1.0750), Vector3(0.0800, 0.7000, 0.1500), "#161616"],
	["Ön panel kablo demeti", "cable_x", Vector3(0.4500, 0.3800, 1.5200), Vector3(0.9000, 0.0400, 0.0400), "#3a3d44"],
	["Güç düğmesi", "button", Vector3(1.3000, 4.1100, 1.3000), Vector3(0.2000, 0.0600, 0.2000), "#c9ccd2"],
	["Monitör ayağı tabanı", "mon_base", Vector3(3.8000, 0.0300, -1.2000), Vector3(1.2000, 0.0600, 0.8000), "#2a2c33"],
	["Monitör boynu", "neck", Vector3(3.8000, 0.5300, -1.2100), Vector3(0.2000, 0.9400, 0.1800), "#2a2c33"],
	["Monitör panel gövdesi", "mon_panel", Vector3(3.8000, 1.9500, -1.0350), Vector3(3.0000, 1.9000, 0.1700), "#1d1f26"],
	["IPS ekran katmanı", "screen", Vector3(3.8000, 1.9500, -0.9400), Vector3(2.8000, 1.7000, 0.0200), "#3aa8ff"],
	["Klavye gövdesi", "kb_base", Vector3(3.8000, 0.0500, 1.0500), Vector3(2.4000, 0.1000, 0.9000), "#24262c"],
	["Mekanik tuş takımı", "keys", Vector3(3.8000, 0.1350, 1.0500), Vector3(2.3000, 0.0700, 0.8000), "#e8e8ee"],
	["Fare", "mouse", Vector3(5.5500, 0.0800, 1.1000), Vector3(0.3000, 0.1200, 0.4000), "#24262c"],
	["Fare altlığı", "pad", Vector3(5.5500, 0.0100, 1.1000), Vector3(0.7000, 0.0200, 1.0000), "#30333b"],
	["Masaüstü hoparlör", "speaker", Vector3(5.7500, 0.4500, -1.0500), Vector3(0.5000, 0.9000, 0.5000), "#24262c"],
	["Sistem çekirdeği", "core", Vector3(-0.7000, 4.8000, 0.0000), Vector3(0.6000, 0.6000, 0.6000), "#62f2ff"],
]
## Dışarıdan model eklemek için: res://assets/models/pc_parts/part_014.glb gibi bir dosya koyun; varsa otomatik yüklenir
## (bkz. AssetLoader). Varsayılan yol optional_glb_path olarak da saklanır.
const GLB_PATTERN := "res://assets/models/pc_parts/part_%03d.glb"

static var _parts: Array = []

static func all() -> Array:
	if _parts.is_empty():
		for i in ROWS.size():
			var r: Array = ROWS[i]
			var p := PCPartData.new()
			p.part_id = i + 1
			p.part_name = r[0]
			p.procedural_shape = r[1]
			p.assembly_position = r[2]
			p.assembly_scale = r[3]
			p.color = Color(r[4])
			p.phase_index = i / PER_PHASE
			p.phase_name = PHASES[p.phase_index]
			p.optional_glb_path = GLB_PATTERN % (i + 1)
			_parts.append(p)
	return _parts

static func part(id: int) -> PCPartData:
	return all()[clampi(id, 1, COUNT) - 1]

## Tüm bilgisayarın sınır kutusu (kamera çerçevesi için)
static func bounds(ids: Array = []) -> AABB:
	var box := AABB()
	var first := true
	for p in all():
		if not ids.is_empty() and not (p.part_id in ids):
			continue
		var b := AABB(p.assembly_position - p.assembly_scale / 2.0, p.assembly_scale)
		box = b if first else box.merge(b)
		first = false
	return box
