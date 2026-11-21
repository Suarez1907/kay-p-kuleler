## 15 bölüm temasının tek kaydı. Renkler spesifikasyondaki hex değerleridir.
class_name ThemeLibrary
extends RefCounted

const COUNT := 15

static var _cache: Array = []


static func all() -> Array:
	if _cache.is_empty():
		_cache = _build()
	return _cache


## 1..15. Aralık dışını aynı 15'li halkaya katlar.
static func theme(id: int) -> ChapterTheme:
	var n := all().size()
	var i := (id - 1) % n
	if i < 0:
		i += n
	return all()[i]


## chapter_index 1 tabanlıdır: (chapter_index - 1) % 15 + 1
static func id_for_chapter(chapter_index: int) -> int:
	return theme(chapter_index).chapter_id


static func _c(hex: String) -> Color:
	return Color(hex)


static func _t(
	id: int, theme_name: String, concept: String, style: int,
	bg_top: String, bg_bottom: String,
	light: String, light_e: float, rot: Vector3,
	amb: String, amb_e: float,
	base: String, top: String, stair: String, accent: String,
	rough: float, metal: float, emit: float,
	led: String, ui_bg: String, ui_accent: String, ui_border: String
) -> ChapterTheme:
	var t := ChapterTheme.new()
	t.chapter_id = id
	t.theme_name = theme_name
	t.concept_name = concept
	t.visual_style = style as ChapterTheme.VisualStyle
	t.bg_top_color = _c(bg_top)
	t.bg_bottom_color = _c(bg_bottom)
	t.light_color = _c(light)
	t.light_energy = light_e
	t.light_rotation_deg = rot
	t.ambient_color = _c(amb)
	t.ambient_energy = amb_e
	t.block_base_color = _c(base)
	t.block_top_color = _c(top)
	t.stair_color = _c(stair)
	t.accent_color = _c(accent)
	t.roughness = rough
	t.metallic = metal
	t.emission_strength = emit
	t.robot_led_color = _c(led)
	t.ui_panel_bg = _c(ui_bg)
	t.ui_accent_color = _c(ui_accent)
	t.ui_border_color = _c(ui_border)
	return t


static func _build() -> Array:
	var S := ChapterTheme.VisualStyle
	return [
		# 1 Kintsugi — mat taş grisi, terrakota üst, altın vurgu, roughness 0.9
		_t(1, "Kintsugi", "Temeller", S.KINTSUGI,
			"#F3E6D8", "#E7D3C4", "#FFE6C8", 0.82, Vector3(-54, 28, 0), "#F0E2D4", 0.42,
			"#9A958E", "#C88A6E", "#C88A6E", "#E8B949", 0.9, 0.04, 0.0,
			"#E8B949", "#F6F1EA", "#C88A6E", "#E8B949"),
		# 2 Saatçi — ceviz, fildişi, fırçalanmış pirinç, metallic 0.35
		_t(2, "Saatçi Masası", "Fonksiyonlar", S.CLOCKWORK,
			"#F0E6D4", "#D7C4A8", "#FFE8C2", 0.78, Vector3(-48, 40, 0), "#E7D7C0", 0.40,
			"#5C3D2E", "#EDE4D3", "#D4AF37", "#D4AF37", 0.55, 0.35, 0.05,
			"#D4AF37", "#F7F3EA", "#5C3D2E", "#D4AF37"),
		# 3 Retro-synth — antrasit, koyu gri tuş, kehribar LED, bakır detay
		_t(3, "Retro-Donanım", "Döngüler", S.RETRO_SYNTH,
			"#2A2428", "#1A1618", "#FFD2A8", 0.62, Vector3(-62, 18, 0), "#3A332E", 0.48,
			"#2B2D32", "#3A3D45", "#C4784A", "#FF7A00", 0.72, 0.22, 0.45,
			"#FF7A00", "#F4F1EC", "#FF7A00", "#FF7A00"),
		# 4 Prizma — obsidyen, buzlu cam, mor #7B2CBF ve camgöbeği #00F5D4, roughness 0.2
		_t(4, "Optik Prizma", "Koşullar", S.PRISM_GLASS,
			"#1B2430", "#121820", "#D6F6F8", 0.70, Vector3(-58, -24, 0), "#1C2830", 0.50,
			"#1F242D", "#A8DADC", "#A8DADC", "#7B2CBF", 0.2, 0.12, 0.35,
			"#00F5D4", "#F3F7F8", "#7B2CBF", "#00F5D4"),
		# 5 Origami — krem karton, pastel mercan ve adaçayı, roughness 0.98
		_t(5, "Origami", "İç İçe Fonksiyonlar", S.ORIGAMI,
			"#F7F1E8", "#E7D5CC", "#FFF6EA", 0.90, Vector3(-50, 22, 0), "#F6EFE6", 0.45,
			"#F4EFE6", "#E09F87", "#A3B899", "#E09F87", 0.98, 0.0, 0.0,
			"#E09F87", "#FBF8F4", "#A3B899", "#E09F87"),
		# 6 Tipografi — kurşun grisi, mürekkep siyahı, vermilyon
		_t(6, "Antik Baskı", "Tetikleyiciler", S.TYPOGRAPHY,
			"#E8E4DE", "#1E1E22", "#F3E6D8", 0.75, Vector3(-56, 36, 0), "#D9D3CC", 0.40,
			"#4A4E54", "#E7E1D6", "#4A4E54", "#E63946", 0.84, 0.06, 0.05,
			"#E63946", "#F7F4F0", "#E63946", "#4A4E54"),
		# 7 Brütalist — ham beton, krom, soğuk beyaz neon, metallic 0.5
		_t(7, "Brütalist Ayna", "Özyineleme", S.BRUTALIST_MIRROR,
			"#D5DDE6", "#B7C0C8", "#F0F8FF", 0.80, Vector3(-68, 12, 0), "#E4EAF0", 0.46,
			"#8D9196", "#D9E2EC", "#D9E2EC", "#F0F8FF", 0.42, 0.5, 0.20,
			"#F0F8FF", "#F4F6F8", "#8D9196", "#F0F8FF"),
		# 8 Teraryum — bakır çerçeve, zümrüt cam, sıvı kehribar
		_t(8, "Simyacının Teraryumu", "Değişkenler", S.TERRARIUM,
			"#1E3A32", "#10241C", "#FFE0A8", 0.72, Vector3(-46, 48, 0), "#1A3330", 0.48,
			"#B87333", "#2D6A4F", "#B87333", "#FFB703", 0.38, 0.42, 0.25,
			"#FFB703", "#F8F3EA", "#FFB703", "#B87333"),
		# 9 Siber dokuma — koyu indigo, fiber-optik camgöbeği, mor iplikler
		_t(9, "Siber-Dokuma", "Işınlanma", S.CYBER_LOOM,
			"#14182E", "#1D2240", "#C9F6F6", 0.55, Vector3(-60, -40, 0), "#1A1E38", 0.50,
			"#1D2240", "#64DFDF", "#64DFDF", "#64DFDF", 0.32, 0.48, 0.40,
			"#64DFDF", "#F2F7F8", "#64DFDF", "#1D2240"),
		# 10 Güneş saati — kumtaşı, mat bronz, alçak sıcak güneş, gölge mavisi ortam
		_t(10, "Kum ve Güneş Saati", "Zamanlama", S.SUNDIAL,
			"#F2D7B5", "#C9A27A", "#FFC58A", 1.05, Vector3(-28, 55, 0), "#7E8CA6", 0.50,
			"#8C6239", "#D9B382", "#8C6239", "#D9B382", 0.86, 0.18, 0.0,
			"#FFC58A", "#FBF6EE", "#D9B382", "#8C6239"),
		# 11 Gözlemevi — gece laciverti, mat beyaz mermer, ince gümüş
		_t(11, "Gözlemevi", "Paralellik", S.OBSERVATORY,
			"#101935", "#0B1020", "#E6EAF6", 0.50, Vector3(-52, -70, 0), "#1A2444", 0.52,
			"#EAEAEA", "#EAEAEA", "#C0C6D4", "#C0C6D4", 0.72, 0.22, 0.08,
			"#C0C6D4", "#F7F7F8", "#101935", "#C0C6D4"),
		# 12 Kinetik — fırçalanmış alüminyum, kobalt, sanayi sarısı, metallic 0.6
		_t(12, "Kinetik Heykel", "Kuleyi Kodlamak", S.KINETIC_SCULPTURE,
			"#E6EAEF", "#C5CED6", "#F4F7FB", 0.88, Vector3(-58, 20, 0), "#E4E8EE", 0.42,
			"#B5BDC4", "#D5DCE2", "#1D4ED8", "#FACC15", 0.40, 0.6, 0.10,
			"#FACC15", "#F6F7F8", "#FACC15", "#1D4ED8"),
		# 13 Blueprint — Prusya mavisi, teknik çizim beyazı, hata kırmızısı
		_t(13, "Röntgen", "Hata Ayıklama", S.BLUEPRINT,
			"#0A2463", "#061433", "#E2F1FF", 0.66, Vector3(-72, 8, 0), "#12306E", 0.48,
			"#0A2463", "#E2F1FF", "#E2F1FF", "#FF4D6D", 0.45, 0.08, 0.30,
			"#FF4D6D", "#F4F8FF", "#FF4D6D", "#0A2463"),
		# 14 Zen — beyaz çakıl, bazalt, kırmızı akçaağaç
		_t(14, "Zen Bahçesi", "Optimizasyon", S.ZEN_GARDEN,
			"#F4F5F2", "#D5D6D0", "#FFF8EE", 0.84, Vector3(-50, 15, 0), "#E6E7E2", 0.44,
			"#2F3133", "#EBECE7", "#2F3133", "#C1121F", 0.93, 0.02, 0.0,
			"#C1121F", "#F7F7F5", "#C1121F", "#2F3133"),
		# 15 Kozmik porselen — mat beyaz, derin uzay, ince altın
		_t(15, "Kozmik Porselen", "Final", S.COSMIC_PORCELAIN,
			"#0B0D17", "#16192A", "#FFF4D0", 0.58, Vector3(-64, -15, 0), "#1A1D2E", 0.50,
			"#F8F9FA", "#F8F9FA", "#F4C430", "#F4C430", 0.84, 0.16, 0.20,
			"#F4C430", "#FBFBFC", "#F4C430", "#0B0D17"),
	]
