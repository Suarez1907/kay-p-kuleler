## LightmapGI toplu fırınlayıcı. Godot 4.8 betiklere LightmapGI.bake() açmadığı için editörün kendi
## "Bake Lightmaps" düğmesi sürülür. Yalnızca KK_BAKE ortam değişkeni varken çalışır:
##   KK_BAKE="res://scenes/a.tscn,res://scenes/b.tscn" godot --editor --path godot-program --rendering-driver vulkan
## Her sahne açılır, içindeki LightmapGI seçilir, düğmeye basılır, .lmbake yazılınca sahne kaydedilir; sonra editör kapanır.
## Sonuçlar user://kk_bake_report.json'a yazılır.
@tool
extends EditorPlugin

var _queue: PackedStringArray = []
var _report := {}

func _enter_tree() -> void:
	if not OS.has_environment("KK_BAKE"):
		return
	_queue = OS.get_environment("KK_BAKE").split(",", false)
	_run.call_deferred()

func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text.strip_edges() == text and (n as Button).is_visible_in_tree():
		return n
	for c in n.get_children(true):
		var b := _find_button(c, text)
		if b != null:
			return b
	return null

func _find_lm(n: Node) -> LightmapGI:
	if n is LightmapGI:
		return n
	for c in n.get_children():
		var r := _find_lm(c)
		if r != null:
			return r
	return null

func _visible_windows(n: Node) -> Array:
	var out := []
	if n is Window and (n as Window).visible and n != get_tree().root:
		out.append(n)
	for c in n.get_children(true):
		out.append_array(_visible_windows(c))
	return out

func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame

func _run() -> void:
	await _frames(30)
	for path in _queue:
		var t0 := Time.get_ticks_msec()
		EditorInterface.open_scene_from_path(path)
		await _frames(20)
		var root := EditorInterface.get_edited_scene_root()
		var lm := _find_lm(root) if root != null else null
		if lm == null:
			_report[path] = {"ok": false, "why": "LightmapGI yok"}
			continue
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(lm)
		EditorInterface.edit_node(lm)
		await _frames(10)
		var btn := _find_button(EditorInterface.get_base_control(), "Bake Lightmaps")
		if btn == null:
			_report[path] = {"ok": false, "why": "Bake düğmesi bulunamadı"}
			continue
		var lmb_path := path.get_basename() + ".lmbake"
		btn.pressed.emit()
		# light_data boşsa editör kayıt yolu sorar: açılan dosya penceresine .lmbake yolu verilir
		var waited := 0
		var answered := false
		while lm.light_data == null and waited < 20000:
			await _frames(1)
			waited += 1
			if not answered and waited % 10 == 0:
				for w in _visible_windows(EditorInterface.get_base_control().get_tree().root):
					if w is FileDialog or w.get_class() == "EditorFileDialog":
						print("KK_BAKE dosya penceresi: ", w.title)
						w.call("set_current_path", lmb_path)
						w.emit_signal("file_selected", lmb_path)
						w.hide()
						answered = true
					elif w is AcceptDialog:
						print("KK_BAKE pencere: ", w.title, " | ", (w as AcceptDialog).dialog_text)
			if answered and waited % 60 == 0:
				for w in _visible_windows(EditorInterface.get_base_control().get_tree().root):
					if w is AcceptDialog and not (w is FileDialog) and w.get_class() != "EditorFileDialog":
						print("KK_BAKE pencere: ", w.title, " | ", (w as AcceptDialog).dialog_text)
						waited = 20000      # hata penceresi: bu sahne başarısız, sıradakine geç
		var ok := lm.light_data != null
		if ok:
			EditorInterface.save_scene()
			await _frames(5)
		var lmb := path.get_basename() + ".lmbake"
		_report[path] = {"ok": ok, "ms": Time.get_ticks_msec() - t0, "lmbake": lmb,
			"bytes": FileAccess.get_file_as_bytes(lmb).size() if FileAccess.file_exists(lmb) else 0}
		print("KK_BAKE ", path, " → ", _report[path])
	var f := FileAccess.open("user://kk_bake_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	print("KK_BAKE_DONE ", JSON.stringify(_report))
	get_tree().quit()
