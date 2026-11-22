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
	"C": {"name": "Klon", "desc": "Robo'nun bulunduğu yere yarı saydam bir klon bırakır; klon F1 satırını Robo ile aynı tur ritminde çalıştırır."},
}

## Koşullar: o = önü açıksa, x = önü kapalıysa, r = herhangi bir röle devresi kapalıysa (akım varsa)
const CONDS := ["", "o", "x", "r"]
## Sayaçlı tekrar: bir blok en fazla bu kadar kez art arda çalışır ("F*3")
const MAX_REPEAT := 4

## "F", "o:F", "x:1", "F*3", "r:L*2" -> {c, k[, n]}
static func parse_ins(v) -> Dictionary:
	if v is Dictionary:
		var d := {"c": String(v["c"]), "k": String(v.get("k", ""))}
		if int(v.get("n", 1)) > 1:
			d["n"] = clampi(int(v["n"]), 2, MAX_REPEAT)
		return d
	var s := String(v)
	var n := 1
	var st := s.find("*")
	if st >= 0:
		n = clampi(int(s.substr(st + 1)), 1, MAX_REPEAT)
		s = s.substr(0, st)
	var i := s.find(":")
	var out := {"c": s, "k": ""} if i < 0 else {"c": s.substr(i + 1), "k": s.substr(0, i)}
	if n > 1:
		out["n"] = n
	return out

static func ins_to_str(ins: Dictionary) -> String:
	var t: String = ins["c"] if ins["k"] == "" else ins["k"] + ":" + ins["c"]
	if int(ins.get("n", 1)) > 1:
		t += "*%d" % int(ins["n"])
	return t

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

## "Röle açıksa" koşulu: herhangi bir devre kapalı (akım geçiyor) mu
static func current_on(s: Dictionary) -> bool:
	var cs = s.get("circuits", {})
	if cs is Dictionary:
		for k in cs:
			if cs[k]:
				return true
	elif cs is Array:
		for v in cs:
			if v:
				return true
	for v in s.get("relays", []):
		if v:
			return true
	return false

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
	if c == "C":
		# klon: bulunduğu yere bırakılır (varsa yenisiyle değişir); F1'i paralel çalıştırır
		var gen := int(s.get("clone", {}).get("gen", 0)) + 1
		s["clone"] = {"p": s["p"], "f": s["f"], "wait": 0, "gen": gen}
		var cf := [PuzzleLogic.clone(s)]
		L.settle(s, cf)
		cf[cf.size() - 1] = s
		return {"state": s, "frames": cf, "bump": false, "pause": false}
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
			s["crumbles"][below["i"]] = int(s["crumbles"][below["i"]]) + 1
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
			var ins: Dictionary = list[idx]
			# sayaçlı tekrar: aynı blok n kez yürütülür, sonra sayaç ilerler
			var reps := int(ins.get("n", 1))
			if reps > 1:
				var left := int(top.get("r", reps)) - 1
				if left > 0:
					top["r"] = left
				else:
					top.erase("r")
					top["pc"] += 1
			else:
				top["pc"] += 1
			if ins["k"] != "":
				var ok := true
				if ins["k"] == "r":
					ok = Program.current_on(s)
				else:
					var open := Program.front_open(L, s)
					ok = (ins["k"] == "o" and open) or (ins["k"] == "x" and not open)
				if not ok:
					# koşul tutmazsa kalan tekrarlar da atlanır
					if top.has("r"):
						top.erase("r")
						top["pc"] += 1
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
	return run_ticks(L, src, ops)


# ---------------------------------------------------------------------------
# Tur tabanlı yürütme: her turda önce klon (varsa) F1'den bir komut, sonra ana Robo kendi satırından bir komut
# yürütür. Direnç bekleme sayacı (wait) bir tur yer. Oyun (main.gd) ve doğrulayıcılar aynı fonksiyonu kullanır.

## Klonu "ana birim" yapan geçici durum (Robo'nun alanları klonunkiyle yer değiştirir; Robo hayalet olur)
static func _as_clone(s: Dictionary) -> Dictionary:
	var c: Dictionary = s["clone"]
	var t := PuzzleLogic.clone(s)
	t["p"] = c["p"]
	t["f"] = c["f"]
	t["wait"] = int(c.get("wait", 0))
	t["dead"] = false
	t["clone"] = {"p": s["p"], "f": s["f"], "wait": int(s.get("wait", 0)), "dead": s["dead"], "gen": c.get("gen", 0), "_main": true}
	return t

static func _from_clone(t: Dictionary) -> Dictionary:
	var m: Dictionary = t["clone"]
	var s := PuzzleLogic.clone(t)
	s["p"] = m["p"]
	s["f"] = m["f"]
	s["wait"] = m["wait"]
	s["dead"] = m["dead"]
	if t["dead"]:
		s["clone"] = {}
	else:
		s["clone"] = {"p": t["p"], "f": t["f"], "wait": int(t.get("wait", 0)), "gen": m.get("gen", 0)}
	return s

## ctx: {prog, main: Runner, clone: Runner|null, gen}. Dönüş: {state, frames, bump, pause, ended, reason, n, cn, wait}
static func tick(L: PuzzleLogic, s: Dictionary, ctx: Dictionary) -> Dictionary:
	var out := {"state": s, "frames": [], "bump": false, "pause": false, "ended": false, "reason": "", "n": null, "cn": null, "wait": false}
	var moved_clone := false
	var cl: Dictionary = s.get("clone", {})
	if not cl.is_empty():
		if ctx.get("clone") == null or int(ctx.get("gen", -1)) != int(cl.get("gen", 0)):
			var p: Dictionary = ctx["prog"]
			ctx["clone"] = Runner.new({"main": p["p1"], "p1": p["p1"], "p2": p["p2"]})
			ctx["gen"] = int(cl.get("gen", 0))
		if int(cl.get("wait", 0)) > 0:
			s = PuzzleLogic.clone(s)
			s["clone"]["wait"] = int(cl["wait"]) - 1
			moved_clone = true
		else:
			var cv := _as_clone(s)
			var n2 = ctx["clone"].next(L, cv)
			out["cn"] = n2
			if n2 != null and not (n2["ins"]["c"] in ["W", "C"]):
				var r2 := cmd_step(L, cv, n2["ins"]["c"])
				if not r2["bump"]:
					s = _from_clone(r2["state"])
					moved_clone = true
	out["state"] = s
	# ana Robo
	if int(s.get("wait", 0)) > 0:
		s = PuzzleLogic.clone(s)
		s["wait"] = int(s["wait"]) - 1
		out["state"] = s
		out["frames"] = [s]
		out["wait"] = true
		return out
	var n = ctx["main"].next(L, s)
	out["n"] = n
	if n == null:
		out["ended"] = true
		out["reason"] = ctx["main"].error if ctx["main"].error != "" else "end"
		if moved_clone:
			out["frames"] = [s]
		return out
	var r := cmd_step(L, s, n["ins"]["c"])
	if r["pause"]:
		out["pause"] = true
		if moved_clone:
			out["frames"] = [s]
		return out
	out["bump"] = r["bump"]
	out["state"] = r["state"]
	out["frames"] = r["frames"] if not r["bump"] else [s]
	return out

## Tüm programı tur tabanlı yürütür (doğrulayıcılar ve testler). ops: molalardaki dünya işlemleri.
static func run_ticks(L: PuzzleLogic, src: Dictionary, ops: Array) -> Dictionary:
	var s := L.initial_state()
	for op in (ops[0] if ops.size() > 0 else []):
		var r0 := world_op(L, s, op)
		if not r0["ok"]:
			return {"result": "op-fail"}
		s = r0["state"]
	var prog := parse_program(src)
	var ctx := {"prog": prog, "main": Runner.new(prog), "clone": null, "gen": -1}
	var pauses := 0
	var ticks := 0
	while ticks < 2000:
		ticks += 1
		if L.is_win(s):
			return {"result": "win", "steps": ctx["main"].steps, "ticks": ticks}
		var t := tick(L, s, ctx)
		s = t["state"]
		if t["pause"]:
			pauses += 1
			for op in (ops[pauses] if ops.size() > pauses else []):
				var r1 := world_op(L, s, op)
				if not r1["ok"]:
					return {"result": "op-fail"}
				s = r1["state"]
			continue
		if t["ended"]:
			return {"result": "win" if L.is_win(s) else t["reason"], "steps": ctx["main"].steps, "ticks": ticks}
		if s["dead"]:
			return {"result": "dead", "steps": ctx["main"].steps, "ticks": ticks}
	return {"result": "limit"}
