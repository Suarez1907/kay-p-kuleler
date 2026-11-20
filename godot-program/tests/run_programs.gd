## Başsız doğrulama: her seviyenin referans programını GDScript yorumlayıcısında çalıştırır.
## godot --headless --path godot-program --script res://tests/run_programs.gd
extends SceneTree

func _init() -> void:
	var f := FileAccess.open("res://data/levels.json", FileAccess.READ)
	var levels: Array = JSON.parse_string(f.get_as_text())
	var ok := 0
	for i in levels.size():
		var L := PuzzleLogic.new()
		L.load_level(levels[i])
		var sol: Dictionary = levels[i]["solution"]
		var r := Program.run_program(L, sol, sol.get("ops", []))
		var blocks := Program.block_count(Program.parse_program(sol))
		var good: bool = r["result"] == "win" and blocks == int(levels[i]["par"])
		if good:
			ok += 1
		print("#%d %s: %s (%s komut, %d blok)" % [i + 1, levels[i]["name"], "TAMAM" if good else "HATA " + r["result"], str(r.get("steps", "-")), blocks])
	print("%d/%d seviye GDScript yorumlayıcısında kazandı" % [ok, levels.size()])
	quit(0 if ok == levels.size() else 1)
