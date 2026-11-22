## Blueprint v2 (Aviyonik / PCB CAD) tasarım sistemi: renk tokenları, 45° pahlı StyleBoxFlat üreticileri,
## merkezi Theme (Type Variations) ve milimetrik ızgara arka planı. Arayüzün tamamı yalnızca bu paleti kullanır.
## Pah: corner_detail = 1 → köşe yayı tek parçalı düz kesim (45°). Kalın kontur (outline_size) kullanılmaz.
class_name BP
extends RefCounted

# ---------- renk tokenları ----------
const BG_NAVY_DEEP := Color("#071224")
const SURFACE_PANEL := Color("#0B192EE6")
const SURFACE_MODAL := Color("#091529F0")
const SCRIM_DARK := Color("#040A14CC")
const BORDER_STEEL := Color("#2B4C7E")
const ACCENT_CYAN := Color("#00E5FF")
const ACCENT_CYAN_PRESSED := Color("#00B8D4")
const ACCENT_CYAN_DARK := Color("#051322")
const ACCENT_AMBER := Color("#F59E0B")
const DANGER_CORAL := Color("#F45B69")
const TEXT_PRIMARY := Color("#F1F5F9")
const TEXT_MUTED := Color("#64748B")
## ikincil metin: muted'ın okunur, hafif cyan tonlu sürümü (teknik etiketler)
const TEXT_LABEL := Color("#7FA6C9")

# ---------- geometri ----------
const R_SMALL := 6      # komut tuşları
const R_STD := 10       # buton / kart
const R_MODAL := 14     # modallar
const BORDER_W := 1.5
const MIN_TOUCH := 44.0

enum Variant { DEFAULT, PRIMARY, AMBER, DANGER, GHOST, CYAN_OUTLINE }

static var _theme: Theme
static var _grid_shader: Shader

## 45° pahlı düz kutu
static func chamfer(bg: Color, radius := R_STD, border := Color(0, 0, 0, 0), bw := BORDER_W, pad := 12.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 1
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.0
	if border.a > 0.0:
		sb.border_color = border
		# 1.5 px: kenarlık tam sayıdır; 2 px çizip kenarı yarı saydam yaparak 1.5 px görünümü verilir
		var w := int(ceil(bw))
		sb.set_border_width_all(w)
		if bw < w:
			sb.border_color = Color(border, border.a * (bw / w))
	sb.set_content_margin_all(pad)
	return sb

static func panel_box(pad := 14.0) -> StyleBoxFlat:
	return chamfer(SURFACE_PANEL, R_STD, BORDER_STEEL, BORDER_W, pad)

static func modal_box(pad := 26.0) -> StyleBoxFlat:
	return chamfer(SURFACE_MODAL, R_MODAL, BORDER_STEEL, BORDER_W, pad)

## Bir varyantın durum stilleri: normal, hover, pressed, disabled
static func variant_styles(v: int, radius := R_STD) -> Dictionary:
	var out := {}
	match v:
		Variant.PRIMARY:
			out["normal"] = chamfer(ACCENT_CYAN, radius)
			out["hover"] = chamfer(ACCENT_CYAN.lightened(0.12), radius)
			out["pressed"] = chamfer(ACCENT_CYAN_PRESSED, radius)
			out["disabled"] = chamfer(Color(ACCENT_CYAN, 0.3), radius)
		Variant.AMBER:
			out["normal"] = chamfer(Color("#F59E0B22"), radius, ACCENT_AMBER)
			out["hover"] = chamfer(Color("#F59E0B33"), radius, ACCENT_AMBER)
			out["pressed"] = chamfer(Color("#F59E0B55"), radius, ACCENT_AMBER)
			out["disabled"] = chamfer(Color("#F59E0B10"), radius, Color(ACCENT_AMBER, 0.35))
		Variant.DANGER:
			out["normal"] = chamfer(Color("#091529CC"), radius, DANGER_CORAL)
			out["hover"] = chamfer(Color("#1a1a2eCC"), radius, DANGER_CORAL)
			out["pressed"] = chamfer(Color("#F45B6933"), radius, DANGER_CORAL)
			out["disabled"] = chamfer(Color("#091529CC"), radius, Color(DANGER_CORAL, 0.35))
		Variant.CYAN_OUTLINE:
			out["normal"] = chamfer(Color("#00E5FF14"), radius, Color(ACCENT_CYAN, 0.85))
			out["hover"] = chamfer(Color("#00E5FF24"), radius, ACCENT_CYAN)
			out["pressed"] = chamfer(Color("#00E5FF40"), radius, ACCENT_CYAN)
			out["disabled"] = chamfer(Color("#00E5FF08"), radius, Color(ACCENT_CYAN, 0.3))
		Variant.GHOST:
			for st in ["normal", "hover", "pressed", "disabled"]:
				out[st] = chamfer(Color(0, 0, 0, 0) if st != "pressed" else Color("#2B4C7E55"), radius)
		_:
			out["normal"] = chamfer(SURFACE_PANEL, radius, BORDER_STEEL)
			out["hover"] = chamfer(Color("#11223AE6"), radius, Color("#3C66A3"))
			out["pressed"] = chamfer(Color("#16304FE6"), radius, ACCENT_CYAN)
			out["disabled"] = chamfer(Color("#0B192E99"), radius, Color(BORDER_STEEL, 0.5))
	for k in out:
		var sb: StyleBoxFlat = out[k]
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
	return out

static func variant_font(v: int) -> Color:
	match v:
		Variant.PRIMARY:
			return ACCENT_CYAN_DARK
		Variant.AMBER:
			return ACCENT_AMBER
		Variant.DANGER:
			return DANGER_CORAL
		Variant.CYAN_OUTLINE:
			return ACCENT_CYAN
	return TEXT_PRIMARY

## Butona varyant stilini uygula (tema değişkeni yerine örnek üzerine; programla kurulan arayüz için)
static func style_button(b: Button, v: int, radius := R_STD) -> void:
	var st := variant_styles(v, radius)
	for k in st:
		b.add_theme_stylebox_override(k, st[k])
	var focus := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("focus", focus)
	var fc := variant_font(v)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.45))
	b.add_theme_constant_override("outline_size", 0)
	b.set_meta("bp_variant", v)

## Eski renk parametresini Blueprint varyantına çevirir (çağıran kod renk vermeye devam edebilir)
static func variant_for(color: Color) -> int:
	if color.is_equal_approx(UIKit.GREEN) or color.is_equal_approx(ACCENT_CYAN):
		return Variant.PRIMARY
	if color.is_equal_approx(UIKit.CORAL) or color.is_equal_approx(DANGER_CORAL):
		return Variant.DANGER
	var h := color.h * 360.0
	if color.s > 0.45 and h > 25.0 and h < 55.0:
		return Variant.AMBER
	return Variant.DEFAULT

# ---------- merkezi tema ----------
static func theme(font: Font, bold: Font) -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT_PRIMARY)
	t.set_constant("outline_size", "Label", 0)
	t.set_color("default_color", "RichTextLabel", TEXT_PRIMARY)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_font("normal_font", "RichTextLabel", font)
	# Button (varsayılan) + Type Variations
	var defs := {"Button": Variant.DEFAULT, "PrimaryButton": Variant.PRIMARY, "AmberButton": Variant.AMBER,
		"DangerButton": Variant.DANGER}
	for name in defs:
		if name != "Button":
			t.set_type_variation(name, "Button")
		var st := variant_styles(defs[name])
		for k in st:
			t.set_stylebox(k, name, st[k])
		t.set_stylebox("focus", name, StyleBoxEmpty.new())
		var fc := variant_font(defs[name])
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(c, name, fc)
		t.set_color("font_disabled_color", name, Color(fc, 0.45))
	t.set_font("font", "PrimaryButton", bold)
	for name in ["ChamferPanel", "ModalPanel"]:
		t.set_type_variation(name, "PanelContainer")
	t.set_stylebox("panel", "ChamferPanel", panel_box())
	t.set_stylebox("panel", "ModalPanel", modal_box())
	t.set_stylebox("panel", "PanelContainer", panel_box())
	# kaydırma çubukları: ince çelik
	var grab := chamfer(Color(BORDER_STEEL, 0.9), 2, Color(0, 0, 0, 0), 0, 3)
	var empty := StyleBoxEmpty.new()
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, empty)
		t.set_stylebox("grabber", sb, grab)
		t.set_stylebox("grabber_highlight", sb, grab)
		t.set_stylebox("grabber_pressed", sb, grab)
	# metin kutusu, SpinBox, CheckButton
	var te := chamfer(Color("#061020F0"), R_STD, BORDER_STEEL, BORDER_W, 14)
	for ty in ["TextEdit", "LineEdit"]:
		t.set_stylebox("normal", ty, te)
		t.set_stylebox("focus", ty, chamfer(Color("#061020F0"), R_STD, ACCENT_CYAN, BORDER_W, 14))
		t.set_color("font_color", ty, TEXT_PRIMARY)
		t.set_color("caret_color", ty, ACCENT_CYAN)
		t.set_color("selection_color", ty, Color(ACCENT_CYAN, 0.3))
	t.set_font_size("font_size", "TextEdit", 15)
	t.set_color("font_color", "CheckButton", TEXT_PRIMARY)
	t.set_color("font_pressed_color", "CheckButton", TEXT_PRIMARY)
	t.set_color("font_hover_color", "CheckButton", TEXT_PRIMARY)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_color("font_color", "TooltipLabel", TEXT_PRIMARY)
	t.set_stylebox("panel", "TooltipPanel", chamfer(SURFACE_MODAL, R_SMALL, BORDER_STEEL, BORDER_W, 8))
	_theme = t
	return t

# ---------- arka plan ----------
## Tam ekran milimetrik ızgara (Mouse Filter: Ignore). hole > 0: merkezde 3D vitrin penceresi.
static func grid_rect(hole := 0.0, opacity := 1.0) -> ColorRect:
	if _grid_shader == null:
		_grid_shader = load("res://shaders/blueprint_grid.gdshader")
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = BG_NAVY_DEEP
	var m := ShaderMaterial.new()
	m.shader = _grid_shader
	m.set_shader_parameter("hole", hole)
	m.set_shader_parameter("opacity", opacity)
	r.material = m
	return r

## Tam ekran karartma perdesi (modallar)
static func scrim() -> ColorRect:
	var d := ColorRect.new()
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.color = SCRIM_DARK
	return d

## İnce amber ilerleme çubuğu (0..1)
class Bar extends Control:
	var value := 0.0
	var color := ACCENT_AMBER
	var track := Color("#2B4C7E66")
	func _init(v := 0.0, h := 4.0) -> void:
		value = v
		custom_minimum_size = Vector2(0, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_value(v: float) -> void:
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), track)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(value, 0.0, 1.0), size.y)), color)

## Teknik etiket: "SYS // PAUSED" gibi küçük, aralıklı, muted-cyan yazı
static func tag(text: String, size := 13, col := TEXT_LABEL) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 0)
	if UIKit.font_bold:
		l.add_theme_font_override("font", UIKit.font_bold)
	return l
