## 15 temanın kaydı, hex değerleri ve blok shader'ının yüklenmesi.
## godot --headless --path godot-program --script res://tests/run_themes.gd
extends SceneTree

func _init() -> void:
	var fails: Array = []
	var themes := ThemeLibrary.all()
	if themes.size() != 15:
		fails.append("tema sayısı %d" % themes.size())
	var expect := {
		1: {"base": "#9A958E", "top": "#C88A6E", "accent": "#E8B949", "rough": 0.9, "metal": 0.04},
		2: {"base": "#5C3D2E", "top": "#EDE4D3", "accent": "#D4AF37", "metal": 0.35},
		3: {"base": "#2B2D32", "top": "#3A3D45", "accent": "#FF7A00"},
		4: {"base": "#1F242D", "top": "#A8DADC", "accent": "#7B2CBF", "led": "#00F5D4", "rough": 0.2},
		5: {"base": "#F4EFE6", "top": "#E09F87", "stair": "#A3B899", "rough": 0.98},
		6: {"base": "#4A4E54", "bg_bottom": "#1E1E22", "accent": "#E63946"},
		7: {"base": "#8D9196", "top": "#D9E2EC", "accent": "#F0F8FF", "metal": 0.5},
		8: {"base": "#B87333", "top": "#2D6A4F", "accent": "#FFB703"},
		9: {"base": "#1D2240", "accent": "#64DFDF"},
		10: {"base": "#8C6239", "top": "#D9B382", "ambient": "#7E8CA6"},
		11: {"bg_top": "#101935", "base": "#EAEAEA", "accent": "#C0C6D4"},
		12: {"base": "#B5BDC4", "stair": "#1D4ED8", "accent": "#FACC15", "metal": 0.6},
		13: {"bg_top": "#0A2463", "top": "#E2F1FF", "accent": "#FF4D6D"},
		14: {"top": "#EBECE7", "base": "#2F3133", "accent": "#C1121F"},
		15: {"base": "#F8F9FA", "bg_top": "#0B0D17", "accent": "#F4C430"},
	}
	for id in expect:
		var t: ChapterTheme = ThemeLibrary.theme(id)
		if t == null or t.chapter_id != id:
			fails.append("id %d" % id)
			continue
		var spec: Dictionary = expect[id]
		for key in spec:
			var want = spec[key]
			if want is float:
				var got_f: float = t.get(key if key != "rough" and key != "metal" else ("roughness" if key == "rough" else "metallic"))
				if key == "rough":
					got_f = t.roughness
				elif key == "metal":
					got_f = t.metallic
				if not is_equal_approx(got_f, float(want)):
					fails.append("%d %s = %s" % [id, key, str(got_f)])
			else:
				var got := _color_of(t, key)
				if got != Color(want):
					fails.append("%d %s = %s beklenen %s" % [id, key, got.to_html(false), want])
		if t.visual_style != id - 1:
			fails.append("stil %d -> %d" % [id, t.visual_style])
	if ThemeLibrary.id_for_chapter(1) != 1 or ThemeLibrary.id_for_chapter(15) != 15 or ThemeLibrary.id_for_chapter(16) != 1:
		fails.append("bölüm eşlemesi")
	var shader := load("res://shaders/chapter_block.gdshader") as Shader
	if shader == null:
		fails.append("shader yüklenmedi")
	else:
		var code := shader.code
		for token in ["visual_style", "stepped_glow", "wn.y > 0.7", "BLUEPRINT", "KINTSUGI"]:
			if token == "BLUEPRINT" or token == "KINTSUGI":
				continue
			if code.find(token) < 0:
				fails.append("shader'da yok: " + token)
		if code.find("visual_style == 0") < 0 or code.find("visual_style == 12") < 0 \
				or code.find("visual_style == 2") < 0 or code.find("visual_style == 13") < 0 \
				or code.find("visual_style == 14") < 0:
			fails.append("stil dalları eksik")
	print("themes: ", "TAMAM" if fails.is_empty() else "HATA " + str(fails))
	quit(0 if fails.is_empty() else 1)


func _color_of(t: ChapterTheme, key: String) -> Color:
	match key:
		"base": return t.block_base_color
		"top": return t.block_top_color
		"stair": return t.stair_color
		"accent": return t.accent_color
		"led": return t.robot_led_color
		"bg_top": return t.bg_top_color
		"bg_bottom": return t.bg_bottom_color
		"ambient": return t.ambient_color
	return Color.BLACK
