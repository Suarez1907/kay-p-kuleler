## Günlük bulmaca: tarihten (YYYYMMDD) tohumlanan, herkes için aynı seviye.
## Kampanya kurucusunun (tools/level_database_builder.gd → B) parçalarıyla kurulur, komut dizisi F1'e ve sayaçlı
## tekrara (F*3) sıkıştırılır ve oyunun kendi tur tabanlı motorunda (Program.run_ticks) doğrulanır. Doğrulanamayan
## aday atılır, sonraki deneme denenir; böylece günlük bulmaca her zaman çözülebilir.
class_name DailyGenerator
extends RefCounted

const LDB := preload("res://tools/level_database_builder.gd")

static func date_seed(d := {}) -> int:
	if d.is_empty():
		d = Time.get_date_dict_from_system()
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])

static func date_label(seed: int) -> String:
	return "%04d-%02d-%02d" % [seed / 10000, (seed / 100) % 100, seed % 100]

static func make(seed: int) -> Dictionary:
	for attempt in 80:
		var r := RandomNumberGenerator.new()
		r.seed = seed * 92821 + attempt * 6007 + 3
		var b := LDB.B.new()
		var n := r.randi_range(6, 9)
		var fuses := []
		for k in n:
			var x := r.randf()
			if x < 0.3:
				b.F(r.randi_range(2, 4))
			elif x < 0.55:
				b.turn("L" if r.randf() < 0.5 else "R")
				b.F(r.randi_range(1, 3))
			elif x < 0.7:
				b.up()
			elif x < 0.8:
				b.jump_up()
			elif x < 0.88:
				b.cap(1)
			else:
				b.F(1)
		if b.failed or b.cmds.size() < 8:
			continue
		var d: Dictionary = b.to_def()
		# yol üstündeki düz geçilen bir-iki bloğu çöken bloğa çevir (bir kez geçilir)
		var path_cells := []
		for e in b.path:
			if e.has("cell"):
				path_cells.append(e["cell"])
		var crumbles := []
		var boxes: Array = d.get("boxes", [])
		for k in mini(2, path_cells.size() / 5):
			var c: Vector3i = path_cells[r.randi_range(1, path_cells.size() - 2)] + Vector3i(0, -1, 0)
			var arr := [c.x, c.y, c.z]
			var bx := [c.x, c.y, c.z, c.x, c.y, c.z]
			if bx in boxes and not (arr in crumbles) and not _has_comp(d, c) and path_cells.count(c + Vector3i(0, 1, 0)) == 1:
				crumbles.append(arr)
				boxes.erase(bx)
		if not crumbles.is_empty():
			d["crumbles"] = crumbles
		var sol := _compress(b.cmds)
		d["cmds"] = _cmds_used(sol)
		d["hint_solution"] = sol
		d["solution"] = sol
		var pc := 0
		for row in ["main", "p1"]:
			pc += (sol.get(row, []) as Array).size()
		d["par_commands"] = pc
		d["par"] = pc
		d["slots"] = {"main": (sol["main"] as Array).size() + 2, "p1": maxi(3, (sol.get("p1", []) as Array).size()), "p2": 0}
		d["reps"] = true
		d["conds"] = false
		d["name"] = "Günlük Bulmaca · " + date_label(seed)
		d["chapter"] = "Günlük"
		d["chapter_tag"] = "GÜNLÜK // " + date_label(seed)
		d["palette"] = seed % 16
		d["id"] = 1000 + seed % 1000
		d["hint"] = "Tekrar eden adımları sayaçla (seçili blok → ×2/×3) ya da F1 ile kısalt. Par: %d blok." % pc
		if _verify(d):
			return d
	return {}

static func _has_comp(d: Dictionary, c: Vector3i) -> bool:
	for cp in d.get("comps", []):
		var p = cp.get("p", null)
		if p is Array and Vector3i(int(p[0]), int(p[1]), int(p[2])) == c:
			return true
	return false

## Ardışık aynı komutları "F*3" sayacına, sonra en iyi tekrar desenini F1'e sıkıştırır
static func _compress(cmds: Array) -> Dictionary:
	var c := LDB.compress(cmds, true, false)
	var main := _runs(c["main"])
	var p1 := _runs(c["p1"])
	var out := {"main": main}
	if not p1.is_empty():
		out["p1"] = p1
	return out

static func _runs(seq: Array) -> Array:
	var out := []
	var i := 0
	while i < seq.size():
		var j := i
		while j < seq.size() and seq[j] == seq[i] and j - i < Program.MAX_REPEAT:
			j += 1
		var n := j - i
		var c: String = seq[i]
		if n > 1 and c in ["F", "L", "R", "J"]:
			out.append("%s*%d" % [c, n])
			i = j
		else:
			out.append(c)
			i += 1
	return out

static func _cmds_used(sol: Dictionary) -> Array:
	var used := {"F": true, "L": true, "R": true}
	for row in ["main", "p1"]:
		for x in sol.get(row, []):
			used[Program.parse_ins(x)["c"]] = true
	used["1"] = true
	var out := []
	for o in ["F", "L", "R", "J", "A", "1"]:
		if used.has(o):
			out.append(o)
	return out

static func _verify(d: Dictionary) -> bool:
	var L := PuzzleLogic.new()
	L.load_level(d.duplicate(true))
	return Program.run_ticks(L, d["hint_solution"], [])["result"] == "win"
