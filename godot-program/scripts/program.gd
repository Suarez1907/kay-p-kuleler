## Kayıp Kuleler — programlama katmanı (web/js/program.js ile birebir aynı kurallar).
## Komutlar, koşullar, fonksiyon çağrıları ve yorumlayıcı. Render'dan bağımsızdır.
class_name Program
extends RefCounted

const UP := Vector3i(0, 1, 0)
const DOWN := Vector3i(0, -1, 0)
const MAX_STEPS := 300
const MAX_DEPTH := 60

const COMMANDS := {
	"F": {"name": "İleri", "desc": "Baktığı yöne bir kare yürür. Merdivenleri çıkar/iner."},
	"L": {"name": "Sola dön", "desc": "Olduğu yerde 90° sola döner."},
	"R": {"name": "Sağa dön", "desc": "Olduğu yerde 90° sağa döner."},
	"J": {"name": "Zıpla", "desc": "Önündeki bir kat yüksek bloğa çıkar ya da bir kat aşağı atlar."},
	"A": {"name": "Kullan", "desc": "Önündeki kolu çevirir, çarkı döndürür, kutuyu iter, topa vurur."},
	"W": {"name": "Mola", "desc": "Programı duraklatır; bu sırada dünyayı değiştirebilirsin."},
	"1": {"name": "F1", "desc": "F1 fonksiyonunu çağırır."},
	"2": {"name": "F2", "desc": "F2 fonksiyonunu çağırır."},
}

## "F", "o:F", "x:1" -> {c, k}
static func parse_ins(v) -> Dictionary:
	if v is Dictionary:
		return {"c": String(v["c"]), "k": String(v.get("k", ""))}
	var s := String(v)
	var i := s.find(":")
	if i < 0:
		return {"c": s, "k": ""}
	return {"c": s.substr(i + 1), "k": s.substr(0, i)}

static func ins_to_str(ins: Dictionary) -> String:
	return ins["c"] if ins["k"] == "" else ins["k"] + ":" + ins["c"]

static func parse_program(src: Dictionary) -> Dictionary:
	var p := {"main": [], "p1": [], "p2": []}
	for row in p:
		for v in src.get(row, []):
			p[row].append(parse_ins(v))
	return p

static func program_to_src(p: Dictionary) -> Dictionary:
	var o := {}
	for row in ["main", "p1", "p2"]:
		if row == "main" or p[row].size() > 0:
			var arr := []
			for ins in p[row]:
				arr.append(ins_to_str(ins))
			o[row] = arr
	return o

static func block_count(p: Dictionary) -> int:
	return p["main"].size() + p["p1"].size() + p["p2"].size()

static func front_open(L: PuzzleLogic, s: Dictionary) -> bool:
	if s["dead"]:
		return false
	var W := L.build_world(s)
	return L.walk_target(s, W, s["p"], s["f"]) != null

static func _jump_target(s: Dictionary, W: Dictionary):
	var P: Vector3i = s["p"]
	var Q: Vector3i = P + PuzzleLogic.DIRS[s["f"]]
	var free := func(p): return not W["solid"].has(p) and not W["ents"].has(p)
	var sup := func(p): return W["solid"].has(p + DOWN) or W["ents"].has(p + DOWN)
	if W["solid"].has(Q) or W["ents"].has(Q):
		if free.call(Q + UP) and free.call(P + UP):
			return Q + UP
		return null
	if sup.call(Q):
		return Q
	var dn: Vector3i = Q + DOWN
	if free.call(dn) and sup.call(dn):
		return dn
	return null

## Tek komutu uygular: {state, frames, bump, pause}
static func cmd_step(L: PuzzleLogic, s0: Dictionary, c: String) -> Dictionary:
	var bump := {"state": s0, "frames": [], "bump": true, "pause": false}
	if s0["dead"]:
		return bump
	var s := PuzzleLogic.clone(s0)
	if c == "L" or c == "R":
		s["f"] = (s["f"] + (3 if c == "L" else 1)) % 4
		return {"state": s, "frames": [s], "bump": false, "pause": false}
	if c == "W":
		return {"state": s0, "frames": [], "bump": false, "pause": true}
	var W := L.build_world(s)
	var P: Vector3i = s["p"]
	var moved_ent = null
	var old_pos = null
	if c == "F" or c == "J":
		var T = L.walk_target(s, W, P, s["f"]) if c == "F" else _jump_target(s, W)
		if c == "J" and T != null and not L.diode_ok(P, T, s["f"]):
			T = null
		if T == null:
			return bump
		old_pos = P
		s["p"] = T
		moved_ent = {"k": "p", "i": 0}
		var below = W["solid"].get(P + DOWN)
		if below != null and below["t"] == "cr" and s["p"] != P:
			s["crumbles"][below["i"]] = 1
	elif c == "A":
		var dv: Vector3i = PuzzleLogic.DIRS[s["f"]]
		var Q: Vector3i = P + dv
		var e = W["ents"].get(Q)
		var sv = W["solid"].get(Q)
		if e != null and e["k"] == "c":
			var C: Vector3i = Q + dv
			if W["solid"].has(C) or W["ents"].has(C):
				return bump
			old_pos = Q
			s["crates"][e["i"]] = C
			moved_ent = {"k": "c", "i": e["i"]}
		elif e != null and e["k"] == "b":
			var C: Vector3i = Q + dv
			var cv = W["solid"].get(C)
			if cv != null and cv["t"] == "lv":
				s["levers"][cv["i"]] = not s["levers"][cv["i"]]
			elif cv != null or W["ents"].has(C):
				return bump
			else:
				s["balls"][e["i"]]["d"] = s["f"]
		elif sv != null and sv["t"] == "lv":
			s["levers"][sv["i"]] = not s["levers"][sv["i"]]
		elif sv != null and sv["t"] == "ck":
			var ck: Dictionary = L.cranks[sv["i"]]
			if not L.try_rotate(s, ck["rot"], ck["dir"]):
				return bump
		else:
			return bump
	else:
		return bump
	s["moves"] += 1
	var frames := [PuzzleLogic.clone(s)]
	if moved_ent != null and L.try_teleport(s, moved_ent, old_pos):
		frames.append(PuzzleLogic.clone(s))
	if moved_ent != null and moved_ent["k"] == "p":
		L.after_arrive(s, frames)
	L.settle(s, frames)
	frames[frames.size() - 1] = s
	return {"state": s, "frames": frames, "bump": false, "pause": false}

## Oyuncunun eli: {t:"rot"|"slide"|"view", i, s}
static func world_op(L: PuzzleLogic, s: Dictionary, op: Dictionary) -> Dictionary:
	if op["t"] == "rot" and L.rotators[int(op["i"])]["fixed"]:
		return {"ok": false}
	return L.step(s, op)


## Yorumlayıcı: çağrı yığını + program sayacı. Kuyruk çağrıları yığını büyütmez.
class Runner:
	var prog: Dictionary
	var stack := [{"p": "main", "pc": 0}]
	var steps := 0
	var error := ""
	var skipped := []

	func _init(p: Dictionary) -> void:
		prog = p

	func finished() -> bool:
		return stack.is_empty()

	## Bir sonraki eylem komutu: {ins, proc, idx} ya da null
	func next(L: PuzzleLogic, s: Dictionary):
		skipped = []
		for guard in 2000:
			if stack.is_empty():
				return null
			var top: Dictionary = stack[stack.size() - 1]
			var list: Array = prog[top["p"]]
			if top["pc"] >= list.size():
				stack.pop_back()
				continue
			var idx: int = top["pc"]
			top["pc"] += 1
			var ins: Dictionary = list[idx]
			if ins["k"] != "":
				var open := Program.front_open(L, s)
				if (ins["k"] == "o" and not open) or (ins["k"] == "x" and open):
					skipped.append({"proc": top["p"], "idx": idx})
					continue
			if ins["c"] == "1" or ins["c"] == "2":
				if top["pc"] >= list.size():
					stack.pop_back()
				if stack.size() >= Program.MAX_DEPTH:
					error = "depth"
					stack = []
					return null
				stack.append({"p": "p1" if ins["c"] == "1" else "p2", "pc": 0})
				continue
			steps += 1
			if steps > Program.MAX_STEPS:
				error = "limit"
				stack = []
				return null
			return {"ins": ins, "proc": top["p"], "idx": idx}
		error = "loop"
		stack = []
		return null


## Tüm programı mola noktalarında `ops` ile çalıştırır (doğrulayıcı ve testler için).
static func run_program(L: PuzzleLogic, src: Dictionary, ops: Array) -> Dictionary:
	var s := L.initial_state()
	var apply := func(st: Dictionary, list) -> Dictionary:
		for op in (list if list != null else []):
			var r := world_op(L, st, op)
			if not r["ok"]:
				return {}
			st = r["state"]
		return st
	s = apply.call(s, ops[0] if ops.size() > 0 else [])
	if s.is_empty():
		return {"result": "op-fail"}
	var run := Runner.new(parse_program(src))
	var pauses := 0
	while true:
		if L.is_win(s):
			return {"result": "win", "steps": run.steps}
		var n = run.next(L, s)
		if n == null:
			return {"result": run.error if run.error != "" else "end", "steps": run.steps}
		var r := cmd_step(L, s, n["ins"]["c"])
		if r["pause"]:
			pauses += 1
			s = apply.call(s, ops[pauses] if ops.size() > pauses else [])
			if s.is_empty():
				return {"result": "op-fail"}
			continue
		s = r["state"]
		if s["dead"]:
			return {"result": "dead", "steps": run.steps}
	return {"result": "end"}
