## Başsız doğrulama: her seviyenin kayıtlı çözümünü GDScript motorunda oynatır.
## Çalıştır: godot --headless --path godot --script res://tests/run_solutions.gd
extends SceneTree

func _init() -> void:
	var f := FileAccess.open("res://data/levels.json", FileAccess.READ)
	var levels: Array = JSON.parse_string(f.get_as_text())
	var fails := 0
	for i in levels.size():
		var L := PuzzleLogic.new()
		L.load_level(levels[i])
		var s := L.initial_state()
		var ok := true
		for a in L.solution:
			var r := L.step(s, a)
			if not r["ok"]:
				ok = false
				break
			s = r["state"]
		var win := ok and L.is_win(s)
		if not win:
			fails += 1
		print("Seviye %d (%s): %s — %d hamle (par %d)" % [i + 1, L.name, "TAMAMLANDI" if win else "BAŞARISIZ", s["moves"], L.par])
		# yol bulma da çalışıyor mu? (başlangıçtan bir hücreye)
		var s0 := L.initial_state()
		var p = L.find_path(s0, s0["p"])
		if p == null:
			print("  find_path hatası")
			fails += 1
	print("SONUÇ: %s" % ("TÜM SEVİYELER GODOT MOTORUNDA ÇÖZÜLDÜ" if fails == 0 else "%d HATA" % fails))
	quit(0 if fails == 0 else 1)
