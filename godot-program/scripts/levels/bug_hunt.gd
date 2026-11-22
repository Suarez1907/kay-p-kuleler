## Hata Avı: bir kampanya seviyesinin doğru çözümüne 1-2 hata enjekte edilir, oyuncu hatalı programı
## en az düzenlemeyle onarır. Hatalar: komut değiştirme (F↔J, L↔R), eksik komut, fazladan komut, iki komutun yer
## değiştirmesi. Üretilen program gerçekten başarısız olmalı (simülasyonla doğrulanır).
## Puan: düzenleme sayısı (satır bazlı Levenshtein) ≤ enjekte edilen hata → 3★, +2'ye kadar 2★, fazlası 1★.
class_name BugHunt
extends RefCounted

const SWAP := {"F": "J", "J": "F", "L": "R", "R": "L", "1": "F", "2": "F", "W": "F", "A": "F", "C": "F"}

static func make(def: Dictionary, seed: int, bugs := 1) -> Dictionary:
	if not def.has("hint_solution"):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var sol: Dictionary = (def["hint_solution"] as Dictionary).duplicate(true)
	for attempt in 40:
		var src := sol.duplicate(true)
		var done := 0
		for b in bugs:
			if _mutate(src, def, rng):
				done += 1
		if done < bugs:
			continue
		var L := PuzzleLogic.new()
		L.load_level(def.duplicate(true))
		if String(Program.run_ticks(L, src, [])["result"]) == "win":
			continue
		var out := def.duplicate(true)
		out["starter"] = src
		out["bugs"] = bugs
		out["chapter"] = "Hata Avı"
		out["chapter_tag"] = "HATA AVI // " + String(def.get("name", "")).to_upper()
		out["hint"] = "Bu program neredeyse doğru ama %d hata var. ÇALIŞTIR ile izle, hatayı bul ve en az değişiklikle düzelt." % bugs
		return out
	return {}

static func _mutate(src: Dictionary, def: Dictionary, rng: RandomNumberGenerator) -> bool:
	var rows := []
	for r in ["main", "p1", "p2"]:
		if src.has(r) and (src[r] as Array).size() > 0:
			rows.append(r)
	if rows.is_empty():
		return false
	var r: String = rows[rng.randi() % rows.size()]
	var arr: Array = src[r]
	var cap := int(def.get("slots", {}).get(r, 0))
	var i := rng.randi() % arr.size()
	match rng.randi() % 4:
		0:  # komut değiştir (koşul/sayaç ekleri korunur)
			var ins := Program.parse_ins(arr[i])
			var c: String = SWAP.get(String(ins["c"]), "F")
			if not c in (def.get("cmds", []) as Array):
				return false
			ins["c"] = c
			arr[i] = Program.ins_to_str(ins)
		1:  # eksik komut
			if arr.size() < 2:
				return false
			arr.remove_at(i)
		2:  # fazladan komut
			if arr.size() >= cap:
				return false
			arr.insert(i, ["F", "L", "R"][rng.randi() % 3])
		_:  # komşu iki komutun yeri
			if arr.size() < 2 or i == arr.size() - 1 or String(arr[i]) == String(arr[i + 1]):
				return false
			var t = arr[i]
			arr[i] = arr[i + 1]
			arr[i + 1] = t
	return true

## Satır bazlı düzenleme mesafesi toplamı (ekle / sil / değiştir = 1)
static func edits(a: Dictionary, b: Dictionary) -> int:
	var n := 0
	for r in ["main", "p1", "p2"]:
		n += _lev(a.get(r, []), b.get(r, []))
	return n

static func _lev(x: Array, y: Array) -> int:
	var prev := []
	for j in y.size() + 1:
		prev.append(j)
	for i in x.size():
		var cur := [i + 1]
		for j in y.size():
			cur.append(mini(mini(cur[j] + 1, prev[j + 1] + 1), prev[j] + (0 if String(x[i]) == String(y[j]) else 1)))
		prev = cur
	return prev[y.size()]

static func stars(edits_used: int, bugs: int) -> int:
	if edits_used <= bugs:
		return 3
	if edits_used <= bugs + 2:
		return 2
	return 1
