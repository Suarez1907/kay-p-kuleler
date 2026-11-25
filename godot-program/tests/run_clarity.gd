## Serbest kamera, kademeli ipucu, verimlilik metni, hata yuvası ve tween temizliği.
## godot --headless --path godot-program --script res://tests/run_clarity.gd
extends SceneTree

func _initialize() -> void:
	var fails: Array = []
	_camera(fails)
	_hints(fails)
	_efficiency(fails)
	_slot(fails)
	_phantom_view(fails)
	await _tweens(fails)
	print("clarity: ", "TAMAM" if fails.is_empty() else "HATA " + str(fails))
	quit(0 if fails.is_empty() else 1)

func _camera(fails: Array) -> void:
	var o := CameraOrbit.new()
	o.adopt(45.0, 45.0, 1.0)
	if o.canonical_view() != 0:
		fails.append("45° bakış 0 değil")
	o.yaw = 80.0
	if o.canonical_view() != 0:
		fails.append("80° hâlâ 0 olmalı")
	o.yaw = 110.0
	if o.canonical_view() != 1:
		fails.append("110° bakış 1 değil")
	o.yaw = 135.0
	if o.canonical_view() != 1:
		fails.append("135° bakış 1 değil")
	if absf(CameraOrbit.yaw_for_view(2) - 225.0) > 0.01:
		fails.append("bakış 2 açısı")
	var aimed := CameraOrbit.approach(10.0, 315.0)
	if absf(wrapf(aimed - 315.0, -180.0, 180.0)) > 0.01:
		fails.append("kısa yol")
	if absf(aimed - 10.0) > 180.0:
		fails.append("kısa yol uzun döndü")
	o.adopt(45.0, 45.0, 1.0)
	o.add_drag_px(100.0, 0.016)
	var dragged := o.yaw
	if absf(dragged - 45.0) < 1.0:
		fails.append("sürükleme açıyı değiştirmedi")
	if absf(fmod(dragged - 45.0, 90.0)) < 0.5:
		fails.append("sürükleme 90°'ye kilitlendi")
	o.release()
	var coast := o.yaw
	for _i in 240:
		o.tick(1.0 / 60.0)
	if o.vel != 0.0 or o.zoom_vel != 0.0 or o.busy():
		fails.append("atalet durmadı vel=%s busy=%s" % [o.vel, o.busy()])
	if absf(o.yaw - coast) < 0.5:
		fails.append("bırakınca süzülmedi")
	if absf(fmod(o.yaw - 45.0, 90.0)) < 0.2:
		fails.append("süzülme 90°'ye oturdu")
	o.zoom_by(10.0)
	if absf(o.zoom - CameraOrbit.ZOOM_MAX) > 0.001:
		fails.append("zoom üst sınır")
	o.zoom_by(0.01)
	if absf(o.zoom - CameraOrbit.ZOOM_MIN) > 0.001:
		fails.append("zoom alt sınır")
	o.zoom = 1.0
	o.zoom_by(1.0)
	if o.zoom_vel != 0.0:
		fails.append("birim zoom hız üretti")

func _hints(fails: Array) -> void:
	var level := {"hint_solution": {"main": ["F*3", "R"], "p1": [], "p2": []}}
	var short := Program.parse_program({"main": ["F"]})
	var h: Dictionary = LevelProgressionManager.next_hint_step(level, short)
	if int(h.get("idx", -1)) != 0 or str(h.get("text", "")).find("sapma") < 0:
		fails.append("F / F*3 sapması: %s" % h)
	var mid := Program.parse_program({"main": ["F*3"]})
	var h2: Dictionary = LevelProgressionManager.next_hint_step(level, mid)
	if int(h2.get("idx", -1)) != 1 or str(h2.get("text", "")).find("Sıradaki") < 0:
		fails.append("sıradaki adım: %s" % h2)
	var extra := Program.parse_program({"main": ["F*3", "R", "F"]})
	var h3: Dictionary = LevelProgressionManager.next_hint_step(level, extra)
	if str(h3.get("text", "")).find("fazla") < 0:
		fails.append("fazla blok: %s" % h3)
	var same := Program.parse_program({"main": ["F*3", "R"]})
	if not LevelProgressionManager.next_hint_step(level, same).is_empty():
		fails.append("çözümle aynı program sapma sayıldı")

func _efficiency(fails: Array) -> void:
	if LevelProgressionManager.efficiency_text(7, 4).find("3 blok fazla") < 0:
		fails.append("fazla verimlilik")
	if LevelProgressionManager.efficiency_text(4, 4).find("tutturuldu") < 0:
		fails.append("par tutturuldu")
	if LevelProgressionManager.efficiency_text(3, 4).find("altında") < 0:
		fails.append("par altı")

func _slot(fails: Array) -> void:
	var s := LevelProgressionManager.failing_slot({"first_bump": {"proc": "p1", "idx": 2}, "last": {"proc": "main", "idx": 0}})
	if s.get("row", "") != "p1" or int(s.get("idx", -1)) != 2:
		fails.append("hata yuvası first_bump")
	var s2 := LevelProgressionManager.failing_slot({"last": {"proc": "main", "idx": 4}})
	if s2.get("row", "") != "main" or int(s2.get("idx", -1)) != 4:
		fails.append("hata yuvası last")
	if not LevelProgressionManager.failing_slot({}).is_empty():
		fails.append("boş kayıt yuva üretti")

func _phantom_view(fails: Array) -> void:
	var d := {"boxes": [[0, 0, 0, 1, 0, 0]], "start": [0, 1, 0], "startDir": 0, "goal": [1, 1, 0],
		"phantoms": [{"cells": [[0, 1, 0]], "view": 1}], "view": 0}
	var L := PuzzleLogic.new()
	L.load_level(d)
	var s := L.initial_state()
	var blocked := L.step(s, {"t": "view", "s": 1})
	if blocked.get("ok", false):
		fails.append("hayalet çakışması bakışı kabul etti")
	var ok := L.step(s, {"t": "view", "s": -1})
	if not ok.get("ok", false):
		fails.append("boş açı reddedildi")
	if int(L.initial_state().get("wait", -1)) != 0:
		fails.append("başlangıç beklemesi")
	if not (L.initial_state().get("circuits", {}) as Dictionary).is_empty():
		fails.append("başlangıç devresi dolu")

func _tweens(fails: Array) -> void:
	var n := Node2D.new()
	root.add_child(n)
	var life := 1
	var tw := n.create_tween()
	tw.tween_property(n, "position:x", 100.0, 5.0)
	var token := life
	life += 1
	if is_instance_valid(tw):
		tw.kill()
	await process_frame
	if is_instance_valid(tw) and tw.is_valid() and tw.is_running():
		fails.append("tween kill sonrası çalışıyor")
	if token == life:
		fails.append("yaşam sayacı artmadı")
	n.queue_free()
