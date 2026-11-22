## Yeni oynanış özellikleri: sayaçlı tekrar (F*3), röle koşulu, sigorta (2 geçişte yanar), günlük bulmaca
## üreticisi (30 gün, hepsi çözülebilir ve aynı tohumdan aynı seviye) ve kule kodu gidiş-dönüşü.
## godot --headless --path godot-program --script res://tests/run_features.gd
extends SceneTree

func _lvl(extra := {}) -> Dictionary:
	var d := {"boxes": [[0, 0, 0, 5, 0, 0]], "start": [0, 1, 0], "startDir": 0, "goal": [5, 1, 0],
		"slots": {"main": 6, "p1": 0, "p2": 0}, "cmds": ["F", "L", "R", "J"]}
	d.merge(extra, true)
	return d

func _run(d: Dictionary, src: Dictionary) -> String:
	var L := PuzzleLogic.new()
	L.load_level(d.duplicate(true))
	return String(Program.run_ticks(L, src, [])["result"])

func _init() -> void:
	var fails := []
	# 1) sayaçlı tekrar: F*4 + F = 5 kare
	if _run(_lvl(), {"main": ["F*4", "F"]}) != "win":
		fails.append("F*4 F kazanmadı")
	if _run(_lvl(), {"main": ["F*4"]}) == "win":
		fails.append("F*4 tek başına kazanmamalı")
	# ayrıştırma / yazma gidiş-dönüş
	var ins := Program.parse_ins("o:F*3")
	if ins["c"] != "F" or ins["k"] != "o" or int(ins["n"]) != 3 or Program.ins_to_str(ins) != "o:F*3":
		fails.append("o:F*3 ayrıştırma")
	if int(Program.parse_ins("F*9").get("n", 1)) != Program.MAX_REPEAT:
		fails.append("tekrar sınırı")
	# fonksiyon çağrısı tekrarı: 1*2 → F1 iki kez
	if _run(_lvl({"slots": {"main": 2, "p1": 3, "p2": 0}, "cmds": ["F", "1"]}), {"main": ["1*2", "F"], "p1": ["F", "F"]}) != "win":
		fails.append("1*2 çağrı tekrarı")
	# koşullu tekrar: önü kapalıysa atlanır (kalan tekrarlar da)
	var wall := _lvl({"boxes": [[0, 0, 0, 2, 0, 0], [3, 1, 0, 3, 1, 0], [2, 0, 1, 2, 0, 5]], "goal": [2, 1, 3]})
	if _run(wall, {"main": ["o:F*4", "R", "F*3"]}) != "win":
		fails.append("o:F*4 duvar önünde durmalı")
	# 2) sigorta: ilk geçişte ayakta kalır, ikinci kez üstünden geçince yanar
	var fz := _lvl({"boxes": [[0, 0, 0, 1, 0, 0], [3, 0, 0, 5, 0, 0]], "fuses": [[2, 0, 0]], "goal": [5, 1, 0]})
	if _run(fz, {"main": ["F*4", "F"]}) != "win":
		fails.append("sigorta ilk geçişte çöktü")
	var fz2 := _lvl({"boxes": [[0, 0, 0, 1, 0, 0], [3, 0, 0, 3, 0, 0]], "fuses": [[2, 0, 0]], "goal": [0, 1, 0], "start": [1, 1, 0]})
	var r2 := _run(fz2, {"main": ["F", "F", "R", "R", "F", "F", "R", "R", "F", "F"]})
	if r2 == "win":
		fails.append("sigorta ikinci geçişte yanmadı")
	var cr := _lvl({"boxes": [[0, 0, 0, 1, 0, 0], [3, 0, 0, 5, 0, 0]], "crumbles": [[2, 0, 0]]})
	if _run(cr, {"main": ["F", "F", "R", "R", "F", "R", "R", "F", "F", "F", "F"]}) == "win":
		fails.append("çöken blok ilk geçişten sonra kalmamalı")
	# 3) röle koşulu: akım yokken atlanır
	var s0 := PuzzleLogic.new()
	s0.load_level(_lvl())
	if Program.current_on(s0.initial_state()):
		fails.append("röle yokken akım var görünüyor")
	# 3b) mantık kapıları ve zamanlayıcı: 0..2 blok, 3 köprü, 4..5 blok; röle 1'de
	var base := {"boxes": [[0, 0, 0, 2, 0, 0], [4, 0, 0, 5, 0, 0]], "start": [0, 1, 0], "startDir": 0, "goal": [5, 1, 0],
		"slots": {"main": 8, "p1": 0, "p2": 0}, "cmds": ["F", "W"], "comps": [{"p": [1, 0, 0], "t": "relay", "id": "G", "mode": "OR"}]}
	var or_l := base.duplicate(true)
	or_l["bridges"] = [{"cells": [[3, 0, 0]], "on": "C:G"}]
	if _run(or_l, {"main": ["F*4", "F"]}) != "win":
		fails.append("OR röle köprüsü açılmadı")
	var not_l := base.duplicate(true)
	not_l["bridges"] = [{"cells": [[3, 0, 0]], "on": "!C:G"}]
	if _run(not_l, {"main": ["F*4", "F"]}) == "win":
		fails.append("NOT köprü röleye basınca kapanmalı")
	var xor_l := base.duplicate(true)
	xor_l["comps"] = [{"p": [1, 0, 0], "t": "relay", "id": "X", "mode": "XOR"}, {"p": [2, 0, 0], "t": "relay", "id": "X", "mode": "XOR"}]
	xor_l["bridges"] = [{"cells": [[3, 0, 0]], "on": "C:X"}]
	# XOR anlıktır: Robo tek röledeyken akım var, iki röle de boşken yok (kilitlenmez)
	var LX := PuzzleLogic.new()
	LX.load_level(xor_l.duplicate(true))
	var sx := LX.initial_state()
	var on0 := Program.current_on(sx)
	sx = Program.cmd_step(LX, sx, "F")["state"]
	var on1 := Program.current_on(sx)
	sx = Program.cmd_step(LX, sx, "F")["state"]
	var on2 := Program.current_on(sx)
	if on0 or not on1 or not on2:
		fails.append("XOR sinyali yanlış (%s %s %s)" % [on0, on1, on2])
	var t_l := base.duplicate(true)
	t_l.erase("comps")
	t_l["bridges"] = [{"cells": [[3, 0, 0]], "on": "T:2"}]
	t_l["slots"] = {"main": 9, "p1": 0, "p2": 0}
	# T:2 → turlar 0-1 açık, 2-3 kapalı, 4-5 açık: beklemeden geçilemez, bir mola ile geçilir
	var tr1 := _run(t_l, {"main": ["F", "F", "F", "F", "F"]})
	var tr2 := _run(t_l, {"main": ["F", "F", "W", "F", "F", "F"]})
	if tr1 == "win" or tr2 != "win":
		fails.append("zamanlayıcı köprü (beklemesiz %s, molalı %s)" % [tr1, tr2])
	# 4) günlük bulmaca: 30 gün, hepsi çözülebilir; aynı tohum aynı seviye; sayaç kullanılabilir
	var made := 0
	var rep_used := 0
	for k in 30:
		var seed := 20261101 + k
		var d := DailyGenerator.make(seed)
		if d.is_empty():
			fails.append("günlük üretilemedi: %d" % seed)
			continue
		made += 1
		if JSON.stringify(DailyGenerator.make(seed)) != JSON.stringify(d):
			fails.append("günlük deterministik değil: %d" % seed)
		if _run(d, d["hint_solution"]) != "win":
			fails.append("günlük çözülemiyor: %d" % seed)
		for x in d["hint_solution"]["main"]:
			if String(x).find("*") >= 0:
				rep_used += 1
				break
	if rep_used == 0:
		fails.append("günlük bulmacalarda sayaç hiç kullanılmadı")
	# 4b) Hata Avı: her kampanya seviyesinden hatalı program üretilir; hatalı başarısız, onarım mesafesi ≤ hata sayısı×2
	var lv_all: Array = LevelProgressionManager.levels()
	var bh := 0
	for i in range(0, 100, 3):
		for bugs in [1, 2]:
			var bd := BugHunt.make(lv_all[i], 1000 + i, bugs)
			if bd.is_empty():
				continue
			bh += 1
			if _run(bd, bd["starter"]) == "win":
				fails.append("hata avı %d: hatalı program kazanıyor" % i)
			var e := BugHunt.edits(bd["starter"], lv_all[i]["hint_solution"])
			if e < 1 or e > bugs * 2:
				fails.append("hata avı %d: düzenleme mesafesi %d" % [i, e])
	if bh < 50:
		fails.append("hata avı az üretildi: %d" % bh)
	if BugHunt.edits({"main": ["F", "L", "F"]}, {"main": ["F", "F"]}) != 1 or BugHunt.stars(3, 1) != 2:
		fails.append("hata avı puanlama")
	# 5) kule kodu gidiş-dönüşü (main.gd'deki biçimle aynı: KKL1 + base64 JSON)
	var lv := _lvl({"name": "Deneme", "fuses": [[2, 0, 0]], "par": 3})
	var code := "KKL1:" + Marshalls.utf8_to_base64(JSON.stringify(lv))
	var back = JSON.parse_string(Marshalls.base64_to_utf8(code.substr(5)))
	if not (back is Dictionary) or back["name"] != "Deneme" or (back["fuses"] as Array).size() != 1:
		fails.append("kule kodu gidiş-dönüşü")
	print("features: günlük %d/30 (sayaçlı %d) · hata avı %d · %s" % [made, rep_used, bh, "TAMAM" if fails.is_empty() else "HATA " + str(fails)])
	quit(0 if fails.is_empty() else 1)
