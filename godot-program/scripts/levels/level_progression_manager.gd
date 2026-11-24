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

## İpucu: oyuncunun programını kayıtlı çözümle karşılaştırıp ilk sapmayı veya sıradaki adımı döndürür.
## Tekrar sayısı (F*3) da karşılaştırılır. Dönüş: {row, idx, ins, text} ya da aynıysa boş sözlük.
static func next_hint_step(level: Dictionary, prog: Dictionary) -> Dictionary:
	var sol: Dictionary = level.get("hint_solution", level.get("solution", {}))
	var names := {"main": "Ana", "p1": "F1", "p2": "F2"}
	for row in ["main", "p1", "p2"]:
		var want: Array = sol.get(row, [])
		var have: Array = prog.get(row, [])
		for i in want.size():
			var w := Program.parse_ins(want[i])
			if i >= have.size():
				return {"row": row, "idx": i, "ins": w, "text": "Sıradaki adım: %s satırının %d. bloğu — %s." % [names[row], i + 1, _cmd_label(w)]}
			var got: Dictionary = have[i]
			if not _same_ins(got, w):
				return {"row": row, "idx": i, "ins": w, "text": "İlk sapma: %s satırının %d. bloğu. Olması gereken: %s. Sende: %s." % [names[row], i + 1, _cmd_label(w), _cmd_label(got)]}
		if have.size() > want.size():
			return {"row": row, "idx": want.size(), "ins": null, "text": "İlk sapma: %s satırında %d. bloktan sonrası fazla — sil." % [names[row], want.size()]}
	return {}

static func _same_ins(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("c", "")) == String(b.get("c", "")) and String(a.get("k", "")) == String(b.get("k", "")) and int(a.get("n", 1)) == int(b.get("n", 1))

static func _cmd_label(ins: Dictionary) -> String:
	var c := String(ins.get("c", ""))
	var name := c
	if Program.COMMANDS.has(c):
		name = String(Program.COMMANDS[c]["name"])
	if int(ins.get("n", 1)) > 1:
		name += " ×%d" % int(ins["n"])
	var cond: String = {"o": " (önü açıksa)", "x": " (önü kapalıysa)", "r": " (röle açıksa)"}.get(String(ins.get("k", "")), "")
	return name + cond

## Bölüm sonu: kullanılan blok ile par_commands / par farkı.
static func efficiency_text(blocks: int, par: int) -> String:
	if par <= 0:
		return "%d blok kullandın." % blocks
	var d := blocks - par
	if d < 0:
		return "Verimlilik: %d blok, par %d — hedefin %d altında." % [blocks, par, -d]
	if d == 0:
		return "Verimlilik: %d blok — par tutturuldu." % blocks
	return "Verimlilik: %d blok, par %d — %d blok fazla. 3 yıldız için parı yakala." % [blocks, par, d]

## Engel anındaki komut yuvası. first_bump varsa o, yoksa son işlenen komut.
static func failing_slot(run_log: Dictionary) -> Dictionary:
	var fb = run_log.get("first_bump", null)
	if fb == null:
		fb = run_log.get("last", null)
	if fb == null or not (fb is Dictionary):
		return {}
	return {"row": String(fb.get("proc", "main")), "idx": int(fb.get("idx", 0))}
