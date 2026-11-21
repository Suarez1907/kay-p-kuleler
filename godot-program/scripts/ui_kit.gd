## Kayıp Kuleler — arayüz kiti: tema, yazı tipi, "basılabilir" kalın butonlar, vektör ikonlar,
## animasyon yardımcıları. Tüm ikonlar kodla çizilir (yazı tipinde olmayan semboller için).
class_name UIKit
extends RefCounted

const INK := Color("#3a3152")
const INK_SOFT := Color("#7a7193")
const CORAL := Color("#ff7a6b")
const GREEN := Color("#36c77b")
const PURPLE := Color("#8a6cf0")
const GOLD := Color("#ffc23d")
const WHITE := Color("#ffffff")

static var font: FontVariation
static var font_bold: FontVariation
static var font_black: FontVariation


static func init_fonts() -> void:
	var base: FontFile = load("res://fonts/Nunito.ttf")
	base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	base.hinting = TextServer.HINTING_LIGHT
	base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
	font = FontVariation.new()
	font.base_font = base
	font.variation_opentype = {wght: 700}
	font_bold = FontVariation.new()
	font_bold.base_font = base
	font_bold.variation_opentype = {wght: 850}
	font_black = FontVariation.new()
	font_black.base_font = base
	font_black.variation_opentype = {wght: 1000}


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 22
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("bold_font", "RichTextLabel", font_black)
	t.set_font("normal_font", "RichTextLabel", font)
	# kaydırma çubukları: ince ve yuvarlak
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(INK, 0.22)
	grab.set_corner_radius_all(6)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	var empty := StyleBoxEmpty.new()
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, empty)
		t.set_stylebox("grabber", sb, grab)
		t.set_stylebox("grabber_highlight", sb, grab)
		t.set_stylebox("grabber_pressed", sb, grab)
	var te := StyleBoxFlat.new()
	te.bg_color = Color("#f4f0fb")
	te.set_corner_radius_all(16)
	te.set_content_margin_all(14)
	t.set_stylebox("normal", "TextEdit", te)
	t.set_stylebox("focus", "TextEdit", te)
	t.set_color("font_color", "TextEdit", INK)
	t.set_font_size("font_size", "TextEdit", 15)
	return t


## Düz kutu stili
static func box(color: Color, radius := 22, shadow := 0, shadow_color := Color(0, 0, 0, 0.12)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 10
	sb.anti_aliasing = true
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_color = shadow_color
		sb.shadow_offset = Vector2(0, shadow * 0.4)
	return sb

## Buzlu cam panel: kırık beyaz yarı saydam zemin, ince açık üst kenarlık, hafif dış gölge
static func frosted_panel(radius := 20, pad := 14) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.98, 0.99, 0.88)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 10
	sb.anti_aliasing = true
	sb.border_width_top = 1
	sb.border_color = Color(1, 1, 1, 0.6)
	sb.shadow_size = 12
	sb.shadow_color = Color(0.16, 0.2, 0.32, 0.14)
	sb.shadow_offset = Vector2(0, -2)
	sb.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", sb)
	return p

## Cam kart (yarı saydam beyaz panel)
static func card(alpha := 0.9, radius := 30, pad := 22) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(1, 1, 1, alpha), radius, 24, Color(0.2, 0.12, 0.35, 0.18))
	sb.border_color = Color(1, 1, 1, 0.9)
	sb.border_width_top = 2
	sb.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", sb)
	return p

static func label(text: String, size := 22, color := INK, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if f:
		l.add_theme_font_override("font", f)
	return l


## Kalın, "dudaklı" (alt kenarı koyu) buton stili: basınca dudak incelir, içerik aşağı iner.
static func style_chunky(b: Button, color: Color, radius := 22, lip := 6, font_color := WHITE) -> void:
	var dark := color.darkened(0.2)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.corner_detail = 10
		sb.anti_aliasing = true
		sb.set_corner_radius_all(radius)
		var c := color
		var l := lip
		if st == "hover":
			c = color.lightened(0.07)
		elif st == "pressed":
			c = color.darkened(0.04)
			l = 1
		elif st == "disabled":
			c = color.lerp(Color("#d9d4e3"), 0.65)
		sb.bg_color = c
		sb.border_color = dark if st != "disabled" else c.darkened(0.12)
		sb.border_width_bottom = l
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 8 + mini(3, lip - l)
		sb.content_margin_bottom = 8
		sb.shadow_color = Color(0.15, 0.08, 0.3, 0.14 if st != "pressed" else 0.06)
		sb.shadow_size = 8 if st != "pressed" else 3
		sb.shadow_offset = Vector2(0, 5 if st != "pressed" else 2)
		if st == "focus":
			sb.draw_center = false
			sb.border_width_bottom = 0
			sb.shadow_size = 0
		b.add_theme_stylebox_override(st, sb)
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(fc, font_color)
	b.add_theme_color_override("font_disabled_color", Color(font_color, 0.6))

## Basma animasyonu: basılınca küçülür, bırakınca yaylanarak geri gelir.
static func juicy(b: Control) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size / 2)
	if b is BaseButton:
		b.button_down.connect(func():
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2(0.92, 0.92), 0.07))
		b.button_up.connect(func():
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

## Metinli kalın buton (isteğe bağlı ikonla). İçerik bir HBox ile ortalanır.
static func button(text: String, color: Color, cb: Callable, size := 24, icon := "", font_color := WHITE, min_h := 64) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, min_h)
	style_chunky(b, color, 22, 6, font_color)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", int(size * 0.4))
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_bottom = -5
	hb.offset_left = 12
	hb.offset_right = -12
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		var ic := Icon.new()
		ic.kind = icon
		ic.color = font_color
		ic.custom_minimum_size = Vector2(size * 0.95, size * 0.95)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ic)
		b.set_meta("icon", ic)
	var lb := label(text, size, font_color, font_black)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.visible = text != ""
	hb.add_child(lb)
	b.add_child(hb)
	b.set_meta("label", lb)
	# metin genişliği kadar en küçük genişlik
	var tw := font_black.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, tw + (size * 1.4 if icon != "" else 0.0) + 40)
	b.pressed.connect(cb)
	juicy(b)
	return b

static func set_text(b: Button, text: String) -> void:
	var lb: Label = b.get_meta("label")
	lb.text = text

## Yuvarlak ikon butonu
static func round_button(icon: String, cb: Callable, size := 60, bg := WHITE, fg := INK) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	style_chunky(b, bg, int(size / 2), 5, fg)
	var ic := Icon.new()
	ic.kind = icon
	ic.color = fg
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = size * 0.24
	ic.offset_right = -size * 0.24
	ic.offset_top = size * 0.2
	ic.offset_bottom = -size * 0.28
	b.add_child(ic)
	b.set_meta("icon", ic)
	b.pressed.connect(cb)
	juicy(b)
	return b

static func set_icon(b: Button, kind: String) -> void:
	var ic: Icon = b.get_meta("icon")
	ic.kind = kind
	ic.queue_redraw()

## Nova avatarı: mor degrade daire içinde robot yüzü
static func nova_avatar(size := 52.0) -> Control:
	var p := PanelContainer.new()
	var sb := box(Color("#7c5cff"), int(size / 2), 8, Color(0.3, 0.15, 0.8, 0.3))
	sb.border_color = Color("#b8a6ff")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(size * 0.16)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ic := Icon.new()
	ic.kind = "nova"
	ic.color = WHITE
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(ic)
	return p

## Hap şeklinde bilgi kutusu
static func pill(child: Control, color := Color(1, 1, 1, 0.85), pad := 14) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(color, 40, 10, Color(0.2, 0.1, 0.35, 0.12))
	sb.content_margin_left = pad + 4
	sb.content_margin_right = pad + 4
	sb.content_margin_top = pad * 0.55
	sb.content_margin_bottom = pad * 0.55
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(child)
	return p


# ---------- animasyon yardımcıları ----------
static func pop_in(n: CanvasItem, delay := 0.0, from := 0.4) -> void:
	if n is Control:
		var c: Control = n
		c.pivot_offset = c.size / 2 if c.size != Vector2.ZERO else c.custom_minimum_size / 2
	n.scale = Vector2(from, from)
	n.modulate.a = 0.0
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(n, "modulate:a", 1.0, 0.2).set_delay(delay)

static func slide_in(n: Control, offset: Vector2, delay := 0.0, dur := 0.45) -> void:
	var target := n.position
	n.position = target + offset
	n.modulate.a = 0.0
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "position", target, dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(n, "modulate:a", 1.0, dur * 0.6).set_delay(delay)

static func pulse(n: CanvasItem, amount := 1.08, dur := 0.9) -> Tween:
	if n is Control:
		(n as Control).pivot_offset = (n as Control).size / 2
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "scale", Vector2(amount, amount), dur / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(n, "scale", Vector2.ONE, dur / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

static func shake(n: Control) -> void:
	var x := n.position.x
	var tw := n.create_tween()
	for k in [10.0, -8.0, 6.0, -4.0, 0.0]:
		tw.tween_property(n, "position:x", x + k, 0.05)


## Vektör ikon. kind: play, pause, stop, step, menu, back, cam_l, cam_r, bulb, reset, sound, sound_off,
## music, music_off, star, star_empty, lock, trash, undo, check, close, gear, save, grid, sparkle, speed, home,
## ve komutlar: F, L, R, J, A, W, 1, 2
class Icon extends Control:
	var kind := "play"
	var color := Color.WHITE
	var stroke := 0.0

	func _draw() -> void:
		var s := size
		var m := minf(s.x, s.y)
		var o := (s - Vector2(m, m)) / 2
		var w := stroke if stroke > 0 else maxf(2.4, m * 0.11)
		var P := func(x: float, y: float) -> Vector2: return o + Vector2(x * m, y * m)
		var col := color
		match kind:
			"play":
				draw_colored_polygon(PackedVector2Array([P.call(0.28, 0.16), P.call(0.86, 0.5), P.call(0.28, 0.84)]), col)
			"pause":
				draw_rect(Rect2(P.call(0.24, 0.16), Vector2(m * 0.17, m * 0.68)), col)
				draw_rect(Rect2(P.call(0.59, 0.16), Vector2(m * 0.17, m * 0.68)), col)
			"stop":
				draw_rect(Rect2(P.call(0.2, 0.2), Vector2(m * 0.6, m * 0.6)), col)
			"step":
				draw_colored_polygon(PackedVector2Array([P.call(0.16, 0.18), P.call(0.64, 0.5), P.call(0.16, 0.82)]), col)
				draw_rect(Rect2(P.call(0.68, 0.18), Vector2(m * 0.15, m * 0.64)), col)
			"menu":
				for y in [0.24, 0.5, 0.76]:
					draw_line(P.call(0.14, y), P.call(0.86, y), col, w, true)
			"back":
				draw_polyline(PackedVector2Array([P.call(0.62, 0.14), P.call(0.28, 0.5), P.call(0.62, 0.86)]), col, w * 1.2, true)
			"close":
				draw_line(P.call(0.2, 0.2), P.call(0.8, 0.8), col, w * 1.1, true)
				draw_line(P.call(0.8, 0.2), P.call(0.2, 0.8), col, w * 1.1, true)
			"check":
				draw_polyline(PackedVector2Array([P.call(0.14, 0.52), P.call(0.4, 0.78), P.call(0.88, 0.24)]), col, w * 1.2, true)
			"cam_l", "cam_r", "reset", "undo":
				# saat yönünde yay + ok ucu; sola dönük olanlar x ekseninde aynalanır
				var mir := kind == "cam_l" or kind == "undo"
				var Q := func(v: Vector2) -> Vector2: return Vector2(m - v.x, v.y) + o if mir else v + o
				var c := Vector2(0.5, 0.54) * m
				var r := m * 0.33
				var pts := PackedVector2Array()
				for k in 21:
					var a := deg_to_rad(-200.0 + 250.0 * k / 20.0)
					pts.append(Q.call(c + Vector2(cos(a), sin(a)) * r))
				draw_polyline(pts, col, w, true)
				var ae := deg_to_rad(50.0)
				var tip := c + Vector2(cos(ae), sin(ae)) * r
				var tang := Vector2(-sin(ae), cos(ae))
				var nrm := Vector2(cos(ae), sin(ae))
				draw_colored_polygon(PackedVector2Array([Q.call(tip + tang * m * 0.16), Q.call(tip + nrm * m * 0.13), Q.call(tip - nrm * m * 0.13)]), col)
				if kind == "reset":
					draw_circle(Q.call(c), m * 0.07, col)
			"nova":
				# Nova: anten, yuvarlak kafa ve iki parlak göz
				draw_line(P.call(0.5, 0.2), P.call(0.5, 0.06), col, w, true)
				draw_circle(P.call(0.5, 0.06), m * 0.07, col)
				var hr := Rect2(P.call(0.14, 0.2), Vector2(m * 0.72, m * 0.6))
				var sb := StyleBoxFlat.new()
				sb.bg_color = col
				sb.set_corner_radius_all(int(m * 0.2))
				draw_style_box(sb, hr)
				var eye := Color("#6a4cff")
				draw_circle(P.call(0.36, 0.48), m * 0.08, eye)
				draw_circle(P.call(0.64, 0.48), m * 0.08, eye)
				draw_line(P.call(0.4, 0.66), P.call(0.6, 0.66), eye, maxf(2.0, w * 0.6), true)
				draw_line(P.call(0.14, 0.5), P.call(0.06, 0.5), col, w, true)
				draw_line(P.call(0.86, 0.5), P.call(0.94, 0.5), col, w, true)
			"bulb":
				draw_arc(P.call(0.5, 0.4), m * 0.25, PI * 0.75, PI * 2.25, 24, col, w, true)
				draw_line(P.call(0.36, 0.6), P.call(0.38, 0.72), col, w, true)
				draw_line(P.call(0.64, 0.6), P.call(0.62, 0.72), col, w, true)
				draw_line(P.call(0.38, 0.74), P.call(0.62, 0.74), col, w, true)
				draw_line(P.call(0.42, 0.88), P.call(0.58, 0.88), col, w, true)
			"sound", "sound_off":
				draw_colored_polygon(PackedVector2Array([P.call(0.12, 0.38), P.call(0.3, 0.38), P.call(0.52, 0.18), P.call(0.52, 0.82), P.call(0.3, 0.62), P.call(0.12, 0.62)]), col)
				if kind == "sound":
					draw_arc(P.call(0.52, 0.5), m * 0.18, -PI / 3.5, PI / 3.5, 12, col, w * 0.9, true)
					draw_arc(P.call(0.52, 0.5), m * 0.33, -PI / 3.5, PI / 3.5, 16, col, w * 0.9, true)
				else:
					draw_line(P.call(0.66, 0.36), P.call(0.9, 0.64), col, w, true)
					draw_line(P.call(0.9, 0.36), P.call(0.66, 0.64), col, w, true)
			"music", "music_off":
				draw_line(P.call(0.38, 0.72), P.call(0.38, 0.2), col, w, true)
				draw_line(P.call(0.78, 0.62), P.call(0.78, 0.12), col, w, true)
				draw_line(P.call(0.38, 0.2), P.call(0.78, 0.12), col, w * 1.3, true)
				draw_circle(P.call(0.28, 0.74), m * 0.12, col)
				draw_circle(P.call(0.68, 0.64), m * 0.12, col)
				if kind == "music_off":
					draw_line(P.call(0.1, 0.1), P.call(0.9, 0.9), col, w, true)
			"star", "star_empty":
				var pts := PackedVector2Array()
				for k in 10:
					var a := -PI / 2 + k * PI / 5
					var r := m * (0.48 if k % 2 == 0 else 0.21)
					pts.append(P.call(0.5, 0.53) + Vector2(cos(a), sin(a)) * r)
				if kind == "star":
					draw_colored_polygon(pts, col)
				else:
					pts.append(pts[0])
					draw_polyline(pts, col, w * 0.8, true)
			"lock":
				draw_arc(P.call(0.5, 0.42), m * 0.18, PI, TAU, 14, col, w, true)
				draw_line(P.call(0.32, 0.42), P.call(0.32, 0.48), col, w, true)
				draw_line(P.call(0.68, 0.42), P.call(0.68, 0.48), col, w, true)
				draw_rect(Rect2(P.call(0.22, 0.46), Vector2(m * 0.56, m * 0.42)), col)
			"trash":
				draw_line(P.call(0.18, 0.26), P.call(0.82, 0.26), col, w, true)
				draw_line(P.call(0.4, 0.16), P.call(0.6, 0.16), col, w, true)
				draw_polyline(PackedVector2Array([P.call(0.26, 0.3), P.call(0.32, 0.86), P.call(0.68, 0.86), P.call(0.74, 0.3)]), col, w, true)
			"gear":
				var c: Vector2 = P.call(0.5, 0.5)
				for k in 8:
					var a := k * TAU / 8
					draw_line(c + Vector2(cos(a), sin(a)) * m * 0.26, c + Vector2(cos(a), sin(a)) * m * 0.44, col, w * 1.4, true)
				draw_arc(c, m * 0.26, 0, TAU, 24, col, w * 1.2, true)
				draw_circle(c, m * 0.09, col)
			"save":
				draw_polyline(PackedVector2Array([P.call(0.5, 0.14), P.call(0.5, 0.62)]), col, w, true)
				draw_polyline(PackedVector2Array([P.call(0.3, 0.44), P.call(0.5, 0.64), P.call(0.7, 0.44)]), col, w, true)
				draw_polyline(PackedVector2Array([P.call(0.16, 0.64), P.call(0.16, 0.86), P.call(0.84, 0.86), P.call(0.84, 0.64)]), col, w, true)
			"grid":
				for gx in 2:
					for gy in 2:
						draw_rect(Rect2(P.call(0.16 + gx * 0.38, 0.16 + gy * 0.38), Vector2(m * 0.3, m * 0.3)), col)
			"home":
				draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.12), P.call(0.9, 0.48), P.call(0.1, 0.48)]), col)
				draw_rect(Rect2(P.call(0.22, 0.46), Vector2(m * 0.56, m * 0.4)), col)
			"speed":
				draw_colored_polygon(PackedVector2Array([P.call(0.1, 0.2), P.call(0.48, 0.5), P.call(0.1, 0.8)]), col)
				draw_colored_polygon(PackedVector2Array([P.call(0.48, 0.2), P.call(0.86, 0.5), P.call(0.48, 0.8)]), col)
			"sparkle":
				var c: Vector2 = P.call(0.5, 0.5)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -m * 0.45), c + Vector2(m * 0.1, -m * 0.1), c + Vector2(m * 0.45, 0), c + Vector2(m * 0.1, m * 0.1), c + Vector2(0, m * 0.45), c + Vector2(-m * 0.1, m * 0.1), c + Vector2(-m * 0.45, 0), c + Vector2(-m * 0.1, -m * 0.1)]), col)
			# ---- komutlar ----
			"F":
				draw_line(P.call(0.5, 0.84), P.call(0.5, 0.22), col, w, true)
				draw_polyline(PackedVector2Array([P.call(0.24, 0.46), P.call(0.5, 0.2), P.call(0.76, 0.46)]), col, w, true)
			"L", "R":
				var mm := -1.0 if kind == "L" else 1.0
				var X := func(x: float) -> float: return 0.5 + (x - 0.5) * mm
				var pts := PackedVector2Array([P.call(X.call(0.3), 0.86), P.call(X.call(0.3), 0.56)])
				for k in range(1, 9):
					var a := PI + PI * 0.5 * k / 8.0
					pts.append(P.call(X.call(0.54 + 0.24 * cos(a)), 0.56 + 0.24 * sin(a)))
				pts.append(P.call(X.call(0.76), 0.32))
				draw_polyline(pts, col, w, true)
				draw_polyline(PackedVector2Array([P.call(X.call(0.6), 0.16), P.call(X.call(0.78), 0.32), P.call(X.call(0.6), 0.48)]), col, w, true)
			"J":
				var pts := PackedVector2Array()
				for k in 13:
					pts.append(P.call(0.18 + 0.62 * k / 12.0, 0.8 - 0.52 * sin(PI * k / 12.0)))
				draw_polyline(pts, col, w, true)
				draw_polyline(PackedVector2Array([P.call(0.64, 0.66), P.call(0.8, 0.8), P.call(0.9, 0.6)]), col, w, true)
			"A":
				draw_arc(P.call(0.5, 0.5), m * 0.13, 0, TAU, 20, col, w, true)
				for k in 8:
					var a := TAU * k / 8.0
					var d := Vector2(cos(a), sin(a))
					draw_line(P.call(0.5, 0.5) + d * m * 0.25, P.call(0.5, 0.5) + d * m * 0.38, col, w, true)
			"W":
				draw_rect(Rect2(P.call(0.27, 0.22), Vector2(m * 0.15, m * 0.56)), col)
				draw_rect(Rect2(P.call(0.58, 0.22), Vector2(m * 0.15, m * 0.56)), col)
			"1", "2":
				var f := UIKit.font_black
				var fs := int(m * 0.5)
				var t := "F" + kind
				var sz := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
				draw_string(f, o + Vector2((m - sz.x) / 2, m * 0.5 + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
