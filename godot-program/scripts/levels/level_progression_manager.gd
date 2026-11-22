## 100 seviyelik devre kampanyasının veri odaklı yönetimi (res://data/levels_100.json).
## 10 donanım fazı × 10 seviye; N. seviye N. bilgisayar parçasını kazandırır. Faz meta verisi (ad, donanım,
## tanıtılan mekanikler) JSON'dan okunur; seviye haritası, ipucu ve geliştirici menüsü buradan beslenir.
## Seviye şeması (her blok için isteğe bağlı bileşen): comps: [{p, component_type: SMD_TRANSISTOR|DIODE|CAPACITOR|
## RESISTOR|RELAY, direction, circuit_id (= target_relay_id), logic_mode: OR|AND, delay_turns, boost_height}],
## bridges: [{cells, on: "C:<circuit_id>"}], enable_clone, hint_solution, par_commands.
class_name LevelProgressionManager
extends RefCounted

const PATH := "res://data/levels_100.json"
const LEVELS_PER_PHASE := 10

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data

static func levels() -> Array:
	return data()["levels"]

static func phases() -> Array:
	return data()["phases"]

static func phase_of(level_idx: int) -> int:
	return clampi(level_idx / LEVELS_PER_PHASE, 0, phases().size() - 1)

static func phase(idx: int) -> Dictionary:
	return phases()[clampi(idx, 0, phases().size() - 1)]

static func level_range(phase_idx: int) -> Array:
	return range(phase_idx * LEVELS_PER_PHASE, mini(levels().size(), (phase_idx + 1) * LEVELS_PER_PHASE))

## Fazda toplanan parça sayısı (unlocked_parts içinde, faz aralığındaki parça kimlikleri)
static func parts_in_phase(phase_idx: int, unlocked_parts: Array) -> int:
	var n := 0
	for id in unlocked_parts:
		if (int(id) - 1) / LEVELS_PER_PHASE == phase_idx:
			n += 1
	return n

## İpucu: oyuncunun programını kayıtlı çözümle karşılaştırıp sıradaki tek adımı döndürür.
## Dönüş: {row, idx, ins, text} ya da program çözümle aynıysa boş sözlük.
static func next_hint_step(level: Dictionary, prog: Dictionary) -> Dictionary:
	var sol: Dictionary = level.get("hint_solution", level.get("solution", {}))
	var names := {"main": "Ana", "p1": "F1", "p2": "F2"}
	for row in ["main", "p1", "p2"]:
		var want: Array = sol.get(row, [])
		var have: Array = prog.get(row, [])
		for i in want.size():
			var w := Program.parse_ins(want[i])
			var ok: bool = i < have.size() and have[i]["c"] == w["c"] and have[i]["k"] == w["k"]
			if not ok:
				var cond: String = {"o": " (yeşil: önü açıksa)", "x": " (turuncu: önü kapalıysa)"}.get(w["k"], "")
				return {"row": row, "idx": i, "ins": w, "text": "%s satırının %d. bloğu: %s%s" % [names[row], i + 1, Program.COMMANDS[w["c"]]["name"], cond]}
		if have.size() > want.size():
			return {"row": row, "idx": want.size(), "ins": null, "text": "%s satırında %d. bloktan sonrasını sil" % [names[row], want.size()]}
	return {}
