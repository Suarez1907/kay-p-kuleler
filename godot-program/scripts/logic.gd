## Kayıp Kuleler — deterministik ızgara fizik motoru.
## web/js/engine.js ile birebir aynı kurallar (çarklar ve ışınlayıcılar dahil).
class_name PuzzleLogic
extends RefCounted

const DIRS := [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]
const UP := Vector3i(0, 1, 0)
const DOWN := Vector3i(0, -1, 0)

var def: Dictionary
var name := ""
var hint := ""
var par := 0
var palette := 0
var statics := {}            # Vector3i -> {t:"b"|"s", d:int}
var min_y := 0
var kill_y := -3
var start := Vector3i.ZERO
var start_dir := 0
var goal := Vector3i.ZERO
var view0 := 0
var crates0 := []
var balls0 := []
var plates := []             # {id, p}
var levers := []             # {id, p, on}
var bridges := []            # {cells, on, door}
var rotators := []           # {pivot:Vector2i, blocks, rot, handle}
var sliders := []            # {blocks, axis, min, max, pos, on, scale}
var scales := []             # {a, b}
var crumbles := []           # Vector3i
var crumble_hp := []         # kaç geçişte çöker: çöken blok 1, sigorta 2
var links := []              # {a, b, d, view}
var cranks := []             # {p, rot, dir}
var portals := []            # {a, b, on}
var phantoms := []           # {cells, views:Array} — yalnızca o açılardan bakınca katı
var comps := {}              # Vector3i (statik blok) -> {t:"diode"|"cap"|"res"|"relay", d, id, ri}; diğerleri SMD transistör
var relay_count := 0
var circuits := {}           # circuit_id -> {mode:"OR"|"AND", cells:[röle üstü hücreler]}

const TYPE_KEYS := {"SMD_TRANSISTOR": "", "DIODE": "diode", "CAPACITOR": "cap", "RESISTOR": "res", "RELAY": "relay"}

## Seviye verisindeki bir bileşeni iç biçime çevirir. Hem kısa ({t, d, id, mode, delay, boost}) hem de
## açık ({component_type, direction, target_relay_id | circuit_id, logic_mode, delay_turns, boost_height}) alan adları desteklenir.
static func normalize_comp(c: Dictionary) -> Dictionary:
	var t := String(c.get("t", ""))
	if c.has("component_type"):
		t = TYPE_KEYS.get(String(c["component_type"]).to_upper(), String(c["component_type"]))
	var id := String(c.get("id", c.get("circuit_id", c.get("target_relay_id", ""))))
	var mode := String(c.get("mode", c.get("logic_mode", ""))).to_upper()
	return {"t": t, "d": int(c.get("d", c.get("direction", 0))), "id": id, "mode": mode,
		"delay": int(c.get("delay", c.get("delay_turns", 1))), "boost": int(c.get("boost", c.get("boost_height", 1))), "ri": -1}
var solution = {}

static func v3(a) -> Vector3i:
	return Vector3i(int(a[0]), int(a[1]), int(a[2]))

static func v3list(arr) -> Array:
	var out := []
	for a in arr:
		out.append(v3(a))
	return out

func load_level(d: Dictionary) -> void:
	def = d
	name = d.get("name", "")
	hint = d.get("hint", "")
	par = int(d.get("par", 0))
	palette = int(d.get("palette", 0))
	var my := 1000000
	for b in d.get("boxes", []):
		var x1 := int(b[0]); var y1 := int(b[1]); var z1 := int(b[2])
		var x2 := int(b[3]); var y2 := int(b[4]); var z2 := int(b[5])
		for x in range(mini(x1, x2), maxi(x1, x2) + 1):
			for y in range(mini(y1, y2), maxi(y1, y2) + 1):
				for z in range(mini(z1, z2), maxi(z1, z2) + 1):
					statics[Vector3i(x, y, z)] = {"t": "b"}
					my = mini(my, y)
	for b in d.get("blocks", []):
		statics[v3(b)] = {"t": "b"}
		my = mini(my, int(b[1]))
	for s in d.get("stairs", []):
		statics[v3(s["p"])] = {"t": "s", "d": int(s["d"])}
		my = mini(my, int(s["p"][1]))
	for r in d.get("remove", []):
		statics.erase(v3(r))
	min_y = 0 if my == 1000000 else my
	kill_y = min_y - 3
	start = v3(d["start"])
	start_dir = int(d.get("startDir", 0))
	goal = v3(d["goal"])
	view0 = int(d.get("view", 0))
	crates0 = v3list(d.get("crates", []))
	balls0 = v3list(d.get("balls", []))
	for p in d.get("plates", []):
		plates.append({"id": String(p["id"]), "p": v3(p["p"])})
	for l in d.get("levers", []):
		levers.append({"id": String(l["id"]), "p": v3(l["p"]), "on": bool(l.get("on", false))})
	for b in d.get("bridges", []):
		bridges.append({"cells": v3list(b["cells"]), "on": b.get("on"), "door": bool(b.get("door", false))})
	for r in d.get("rotators", []):
		rotators.append({"pivot": Vector2i(int(r["pivot"][0]), int(r["pivot"][1])), "blocks": v3list(r["blocks"]),
			"rot": int(r.get("rot", 0)), "handle": v3(r["handle"]) if r.has("handle") else null,
			"fixed": bool(r.get("fixed", false))})
	for s in d.get("sliders", []):
		sliders.append({"blocks": v3list(s["blocks"]), "axis": v3(s["axis"]), "min": int(s["min"]), "max": int(s["max"]),
			"pos": int(s.get("pos", 0)), "on": s.get("on"), "scale": false})
	for sc in d.get("scales", []):
		scales.append({"a": int(sc["a"]), "b": int(sc["b"])})
		sliders[int(sc["a"])]["scale"] = true
		sliders[int(sc["b"])]["scale"] = true
	crumbles = v3list(d.get("crumbles", []))
	crumble_hp = []
	for c in crumbles:
		crumble_hp.append(1)
	# sigorta: iki kez üstünden geçilince yanar (çöker)
	for f in v3list(d.get("fuses", [])):
		crumbles.append(f)
		crumble_hp.append(2)
	for ln in d.get("links", []):
		links.append({"a": v3(ln["a"]), "b": v3(ln["b"]), "d": int(ln["d"]), "view": int(ln["view"])})
	for c in d.get("cranks", []):
		cranks.append({"p": v3(c["p"]), "rot": int(c["rot"]), "dir": int(c.get("dir", 1))})
	for pt in d.get("portals", []):
		portals.append({"a": v3(pt["a"]), "b": v3(pt["b"]), "on": pt.get("on")})
	for ph in d.get("phantoms", []):
		var vw = ph["view"]
		var views := []
		if vw is Array:
			for v in vw:
				views.append(int(v))
		else:
			views.append(int(vw))
		phantoms.append({"cells": v3list(ph["cells"]), "views": views})
	for c in d.get("comps", []):
		var e := normalize_comp(c)
		if e["t"] == "relay" and e["mode"] == "":
			e["ri"] = relay_count
			relay_count += 1
		if e["t"] == "relay" and e["mode"] != "":
			if not circuits.has(e["id"]):
				circuits[e["id"]] = {"mode": e["mode"], "cells": []}
			circuits[e["id"]]["cells"].append(v3(c["p"]) + UP)
		comps[v3(c["p"])] = e
	solution = d.get("solution", {})

func is_manual(i: int) -> bool:
	return sliders[i]["on"] == null and not sliders[i]["scale"]

func initial_state() -> Dictionary:
	var s := {
		"p": start, "f": start_dir, "crates": crates0.duplicate(), "balls": [],
		"levers": [], "rots": [], "slides": [], "bridges": [], "crumbles": [], "relays": [],
		"wait": 0, "clone": {}, "circuits": {},
		"view": view0, "dead": false, "moves": 0,
	}
	for b in balls0:
		s["balls"].append({"p": b, "d": -1})
	for l in levers:
		s["levers"].append(l["on"])
	for r in rotators:
		s["rots"].append(r["rot"])
	for sl in sliders:
		s["slides"].append(sl["pos"])
	for b in bridges:
		s["bridges"].append(false)
	for c in crumbles:
		s["crumbles"].append(0)
	for k in relay_count:
		s["relays"].append(false)
	settle(s, null)
	return s

static func clone(s: Dictionary) -> Dictionary:
	return s.duplicate(true)

static func state_key(s: Dictionary) -> String:
	var parts := [str(s["p"])]
	parts.append(str(s["crates"]))
	var bl := []
	for b in s["balls"]:
		bl.append("x" if b == null else str(b["p"]))
	parts.append(str(bl))
	parts.append(str(s["levers"]))
	parts.append(str(s["rots"]))
	parts.append(str(s["slides"]))
	parts.append(str(s["bridges"]))
	parts.append(str(s["crumbles"]))
	parts.append(str(s["view"]))
	parts.append(str(s.get("relays", [])))
	parts.append(str(s.get("wait", 0)) + str(s.get("clone", {})) + str(s.get("circuits", {})))
	return "|".join(parts)

# ---- dinamik bloklar ----
static func rot_point(pivot: Vector2i, p: Vector3i, steps: int) -> Vector3i:
	var dx := p.x - pivot.x
	var dz := p.z - pivot.y
	for k in range(((steps % 4) + 4) % 4):
		var t := dx
		dx = dz
		dz = -t
	return Vector3i(pivot.x + dx, p.y, pivot.y + dz)

func rotator_cells(i: int, rot: int) -> Array:
	var out := []
	for b in rotators[i]["blocks"]:
		out.append(rot_point(rotators[i]["pivot"], b, rot))
	return out

func slider_cells(i: int, pos: int) -> Array:
	var out := []
	var ax: Vector3i = sliders[i]["axis"]
	for b in sliders[i]["blocks"]:
		out.append(b + ax * pos)
	return out

func build_world(s: Dictionary, skip_rot := -1, skip_slide := -1) -> Dictionary:
	var solid := statics.duplicate()
	for i in bridges.size():
		if s["bridges"][i]:
			for c in bridges[i]["cells"]:
				solid[c] = {"t": "br", "i": i}
	for i in rotators.size():
		if i != skip_rot:
			for c in rotator_cells(i, s["rots"][i]):
				solid[c] = {"t": "rot", "i": i}
	for i in sliders.size():
		if i != skip_slide:
			for c in slider_cells(i, s["slides"][i]):
				solid[c] = {"t": "sl", "i": i}
	for i in crumbles.size():
		if int(s["crumbles"][i]) < int(crumble_hp[i]):
			solid[crumbles[i]] = {"t": "cr", "i": i}
	for i in phantoms.size():
		if int(s["view"]) in phantoms[i]["views"]:
			for c in phantoms[i]["cells"]:
				solid[c] = {"t": "ph", "i": i}
	for i in levers.size():
		solid[levers[i]["p"]] = {"t": "lv", "i": i}
	for i in cranks.size():
		solid[cranks[i]["p"]] = {"t": "ck", "i": i}
	var ents := {}
	if not s["dead"]:
		ents[s["p"]] = {"k": "p", "i": 0}
	for i in s["crates"].size():
		if s["crates"][i] != null:
			ents[s["crates"][i]] = {"k": "c", "i": i}
	for i in s["balls"].size():
		if s["balls"][i] != null:
			ents[s["balls"][i]["p"]] = {"k": "b", "i": i}
	return {"solid": solid, "ents": ents}

static func _supported(W: Dictionary, p: Vector3i) -> bool:
	var k := p + DOWN
	return W["solid"].has(k) or W["ents"].has(k)

static func _free(W: Dictionary, p: Vector3i) -> bool:
	return not W["solid"].has(p) and not W["ents"].has(p)

func _signals(s: Dictionary, W: Dictionary) -> Dictionary:
	var sig := {}
	for pl in plates:
		sig[pl["id"]] = sig.get(pl["id"], false) or W["ents"].has(pl["p"])
	for i in levers.size():
		sig[levers[i]["id"]] = s["levers"][i]
	for c in comps.values():
		if c["t"] == "relay" and c["mode"] == "":
			sig[c["id"]] = bool(s["relays"][c["ri"]])
	for cid in circuits:
		sig["C:" + cid] = bool(s.get("circuits", {}).get(cid, false))
	return sig

## Röle devresi: üstünde Robo, klon ya da kutu duran röle basılıdır. OR: biri yeter; AND: hepsi aynı anda.
## Koşul sağlandığı an devre kilitlenir (köprü kalıcı açılır).
func relay_pressed(s: Dictionary, W: Dictionary, cell: Vector3i) -> bool:
	if not s["dead"] and s["p"] == cell:
		return true
	var cl: Dictionary = s.get("clone", {})
	if not cl.is_empty() and cl["p"] == cell:
		return true
	return W["ents"].has(cell)

func _update_circuits(s: Dictionary, W: Dictionary) -> bool:
	var changed := false
	for cid in circuits:
		if s["circuits"].get(cid, false):
			continue
		var c: Dictionary = circuits[cid]
		var n := 0
		for cell in c["cells"]:
			if relay_pressed(s, W, cell):
				n += 1
		var on: bool = n > 0 if c["mode"] == "OR" else n == c["cells"].size()
		if on:
			s["circuits"][cid] = true
			changed = true
	return changed

static func eval_sig(sig: Dictionary, expr) -> bool:
	if expr == null:
		return false
	if expr is Array:
		for e in expr:
			if not eval_sig(sig, e):
				return false
		return true
	var e := String(expr)
	if e.begins_with("!"):
		return not sig.get(e.substr(1), false)
	return bool(sig.get(e, false))

func current_signals(s: Dictionary) -> Dictionary:
	return _signals(s, build_world(s))

static func _get_ent(s: Dictionary, e: Dictionary) -> Vector3i:
	match e["k"]:
		"p": return s["p"]
		"c": return s["crates"][e["i"]]
		_: return s["balls"][e["i"]]["p"]

static func _set_ent(s: Dictionary, e: Dictionary, p: Vector3i) -> void:
	match e["k"]:
		"p": s["p"] = p
		"c": s["crates"][e["i"]] = p
		_: s["balls"][e["i"]]["p"] = p

## Işınlayıcı: varlık başka bir hücreden aktif portal hücresine girerse diğer uca ışınlanır.
func try_teleport(s: Dictionary, e: Dictionary, old_pos) -> bool:
	if portals.is_empty():
		return false
	var cur := _get_ent(s, e)
	if old_pos != null and cur == old_pos:
		return false
	var W := build_world(s)
	var sig := _signals(s, W)
	for pt in portals:
		if pt["on"] != null and not eval_sig(sig, pt["on"]):
			continue
		var dest = pt["b"] if cur == pt["a"] else (pt["a"] if cur == pt["b"] else null)
		if dest != null and _free(W, dest):
			_set_ent(s, e, dest)
			return true
	return false

static func _carried(W: Dictionary, cells: Array) -> Array:
	var out := []
	var seen := {}
	var frontier := []
	for c in cells:
		frontier.append(c + UP)
	while frontier.size() > 0:
		var nf := []
		for p in frontier:
			if seen.has(p):
				continue
			if W["ents"].has(p):
				seen[p] = true
				out.append({"e": W["ents"][p], "p": p})
				nf.append(p + UP)
		frontier = nf
	return out

func _move_platform(s: Dictionary, skip_rot: int, skip_slide: int, old_cells: Array, new_cells: Array, f: Callable, dir_turn: int) -> bool:
	var W := build_world(s, skip_rot, skip_slide)
	var car := _carried(W, old_cells)
	var car_keys := {}
	for c in car:
		car_keys[c["p"]] = true
	var new_set := {}
	for c in new_cells:
		new_set[c] = true
		if W["solid"].has(c):
			return false
		if W["ents"].has(c) and not car_keys.has(c):
			return false
	var moved := []
	for c in car:
		var np: Vector3i = f.call(c["p"])
		if W["solid"].has(np) or new_set.has(np):
			return false
		if W["ents"].has(np) and not car_keys.has(np):
			return false
		moved.append({"e": c["e"], "np": np})
	for m in moved:
		_set_ent(s, m["e"], m["np"])
		if m["e"]["k"] == "p" and dir_turn != 0:
			s["f"] = (s["f"] + dir_turn + 4) % 4
	return true

func try_rotate(s: Dictionary, i: int, dir: int) -> bool:
	var pivot: Vector2i = rotators[i]["pivot"]
	var ok := _move_platform(s, i, -1, rotator_cells(i, s["rots"][i]), rotator_cells(i, s["rots"][i] + dir),
		func(p): return PuzzleLogic.rot_point(pivot, p, dir), 3 if dir > 0 else 1)
	if ok:
		s["rots"][i] = ((s["rots"][i] + dir) % 4 + 4) % 4
	return ok

func _try_slide(s: Dictionary, i: int, dir: int) -> bool:
	var np: int = s["slides"][i] + dir
	if np < sliders[i]["min"] or np > sliders[i]["max"]:
		return false
	var a: Vector3i = sliders[i]["axis"] * dir
	var ok := _move_platform(s, -1, i, slider_cells(i, s["slides"][i]), slider_cells(i, np), func(p): return p + a, 0)
	if ok:
		s["slides"][i] = np
	return ok

func _weight_on(s: Dictionary, i: int) -> int:
	return _carried(build_world(s), slider_cells(i, s["slides"][i])).size()

func settle(s: Dictionary, frames) -> void:
	for tick in range(200):
		var changed := false
		var W := build_world(s)
		if not circuits.is_empty() and s.has("circuits") and _update_circuits(s, W):
			changed = true
		var sig := _signals(s, W)
		for i in bridges.size():
			var want := eval_sig(sig, bridges[i]["on"])
			if want and not s["bridges"][i]:
				var clear := true
				for c in bridges[i]["cells"]:
					if W["ents"].has(c):
						clear = false
				if clear:
					s["bridges"][i] = true
					changed = true
			elif not want and s["bridges"][i]:
				s["bridges"][i] = false
				changed = true
		for i in sliders.size():
			var sl: Dictionary = sliders[i]
			if sl["on"] != null:
				var target: int = sl["max"] if eval_sig(sig, sl["on"]) else sl["min"]
				if target != s["slides"][i]:
					if _try_slide(s, i, 1 if target > s["slides"][i] else -1):
						changed = true
		for sc in scales:
			var wa := _weight_on(s, sc["a"])
			var wb := _weight_on(s, sc["b"])
			var sg := signi(wa - wb)
			var ta := -sg
			var tb := sg
			if s["slides"][sc["a"]] != ta or s["slides"][sc["b"]] != tb:
				var da := signi(ta - s["slides"][sc["a"]])
				var db := signi(tb - s["slides"][sc["b"]])
				var backup := clone(s)
				var ok := true
				if da != 0:
					ok = _try_slide(s, sc["a"], da)
				if ok and db != 0:
					ok = _try_slide(s, sc["b"], db)
				if ok:
					changed = true
				else:
					for k in backup:
						s[k] = backup[k]
		W = build_world(s)
		var ents := []
		if not s["dead"]:
			ents.append({"k": "p", "i": 0})
		for i in s["crates"].size():
			if s["crates"][i] != null:
				ents.append({"k": "c", "i": i})
		for i in s["balls"].size():
			if s["balls"][i] != null:
				ents.append({"k": "b", "i": i})
		ents.sort_custom(func(a, b): return PuzzleLogic._get_ent(s, a).y < PuzzleLogic._get_ent(s, b).y)
		for e in ents:
			var p := _get_ent(s, e)
			if not _supported(W, p):
				var np := p + DOWN
				W["ents"].erase(p)
				if np.y < kill_y:
					match e["k"]:
						"p": s["dead"] = true
						"c": s["crates"][e["i"]] = null
						_: s["balls"][e["i"]] = null
				else:
					_set_ent(s, e, np)
					W["ents"][np] = e
					if try_teleport(s, e, p):
						W["ents"].erase(np)
						W["ents"][_get_ent(s, e)] = e
				changed = true
			elif e["k"] == "b" and s["balls"][e["i"]]["d"] >= 0:
				var b: Dictionary = s["balls"][e["i"]]
				var np: Vector3i = p + DIRS[b["d"]]
				var sv = W["solid"].get(np)
				if sv == null and not W["ents"].has(np):
					W["ents"].erase(p)
					b["p"] = np
					W["ents"][np] = e
					if try_teleport(s, e, p):
						W["ents"].erase(np)
						W["ents"][b["p"]] = e
					changed = true
				else:
					if sv != null and sv["t"] == "lv":
						s["levers"][sv["i"]] = not s["levers"][sv["i"]]
					b["d"] = -1
					changed = true
		if not changed:
			return
		if frames != null:
			frames.append(clone(s))

## Robo'nun durduğu hücrenin altındaki devre elemanı (yoksa boş sözlük = SMD transistör)
func comp_at(p: Vector3i) -> Dictionary:
	return comps.get(p + DOWN, {})

## Diyot: üstüne yalnızca ok yönünde girilir ve yalnızca ok yönünde çıkılır
func diode_ok(P: Vector3i, T, d: int) -> bool:
	if T == null:
		return false
	var a := comp_at(P)
	if a.get("t", "") == "diode" and int(a["d"]) != d:
		return false
	var b := comp_at(T)
	if b.get("t", "") == "diode" and int(b["d"]) != d:
		return false
	return true

## Varıştan sonra: röle tetiklenir, direnç bir adım bekletir, kondansatör ileri + yukarı fırlatır
func after_arrive(s: Dictionary, frames) -> void:
	if s["dead"]:
		return
	var c := comp_at(s["p"])
	match String(c.get("t", "")):
		"relay":
			if c["mode"] == "":
				s["relays"][c["ri"]] = not s["relays"][c["ri"]]
		"res":
			# direnç: Robo delay_turns tur bekler (tur tabanlı yürütücü bekleme sayacını düşer)
			s["wait"] = int(s.get("wait", 0)) + maxi(1, int(c.get("delay", 1)))
			if frames != null:
				frames.append(clone(s))
		"cap":
			var W := build_world(s)
			var T: Vector3i = s["p"] + DIRS[s["f"]] + UP * maxi(1, int(c.get("boost", 1)))
			if _free(W, T) and _supported(W, T) and _free(W, s["p"] + UP) and diode_ok(s["p"], T, s["f"]):
				s["p"] = T
				s["moves"] += 1
				if frames != null:
					frames.append(clone(s))

## Diyot yüzünden mi yürünemiyor? (yol açık ama diyot ters yönde)
func diode_blocked(s: Dictionary) -> bool:
	var W := build_world(s)
	var T = _walk_target_raw(s, W, s["p"], s["f"])
	return T != null and not diode_ok(s["p"], T, s["f"])

func walk_target(s: Dictionary, W: Dictionary, P: Vector3i, d: int):
	var T = _walk_target_raw(s, W, P, d)
	return T if T != null and diode_ok(P, T, d) else null

func _walk_target_raw(s: Dictionary, W: Dictionary, P: Vector3i, d: int):
	var Q: Vector3i = P + DIRS[d]
	for ln in links:
		if ln["view"] != s["view"]:
			continue
		if P == ln["a"] and d == ln["d"] and _free(W, ln["b"]) and _supported(W, ln["b"]):
			return ln["b"]
		if P == ln["b"] and d == (ln["d"] + 2) % 4 and _free(W, ln["a"]) and _supported(W, ln["a"]):
			return ln["a"]
	var qs = W["solid"].get(Q)
	if qs == null and not W["ents"].has(Q):
		if _supported(W, Q):
			return Q
		var below = W["solid"].get(P + DOWN)
		var Q2 := Q + DOWN
		if below != null and below["t"] == "s" and d == (below["d"] + 2) % 4 and _free(W, Q2) and _supported(W, Q2):
			return Q2
		return null
	if qs != null and qs["t"] == "s" and qs["d"] == d:
		var Q2 := Q + UP
		if _free(W, Q2):
			return Q2
	return null

## a: {t:"move", d} | {t:"rot", i, s} | {t:"slide", i, s} | {t:"view", s}
func step(s0: Dictionary, a: Dictionary) -> Dictionary:
	if s0["dead"]:
		return {"ok": false}
	var s := clone(s0)
	var frames := []
	var t := String(a["t"])
	if t == "move":
		var W := build_world(s)
		var P: Vector3i = s["p"]
		var d := int(a["d"])
		var Q: Vector3i = P + DIRS[d]
		s["f"] = d
		var e = W["ents"].get(Q)
		var sv = W["solid"].get(Q)
		var moved := false
		if e != null and e["k"] == "c":
			var C: Vector3i = Q + DIRS[d]
			if not _free(W, C):
				return {"ok": false}
			s["crates"][e["i"]] = C
			s["p"] = Q
			moved = true
		elif e != null and e["k"] == "b":
			var C: Vector3i = Q + DIRS[d]
			if not _free(W, C):
				var cv = W["solid"].get(C)
				if cv != null and cv["t"] == "lv":
					s["levers"][cv["i"]] = not s["levers"][cv["i"]]
				else:
					return {"ok": false}
			else:
				s["balls"][e["i"]]["d"] = d
		elif sv != null and sv["t"] == "lv":
			s["levers"][sv["i"]] = not s["levers"][sv["i"]]
		else:
			var T = walk_target(s, W, P, d)
			if T == null:
				return {"ok": false}
			s["p"] = T
			moved = true
		if moved:
			var below = W["solid"].get(P + DOWN)
			if below != null and below["t"] == "cr" and s["p"] != P:
				s["crumbles"][below["i"]] = int(s["crumbles"][below["i"]]) + 1
			s["moves"] += 1
			frames.append(clone(s))
			after_arrive(s, frames)
			settle(s, frames)
			frames[frames.size() - 1] = s
			return {"ok": true, "state": s, "frames": frames}
	elif t == "rot":
		if not try_rotate(s, int(a["i"]), int(a["s"])):
			return {"ok": false}
	elif t == "slide":
		if not is_manual(int(a["i"])):
			return {"ok": false}
		if not _try_slide(s, int(a["i"]), int(a["s"])):
			return {"ok": false}
	elif t == "view":
		var W0 := build_world(s0)
		s["view"] = ((s["view"] + int(a["s"])) % 4 + 4) % 4
		# beliren hayalet blok bir varlığın içine doğamaz
		for ph in phantoms:
			if int(s["view"]) in ph["views"] and not (int(s0["view"]) in ph["views"]):
				for c in ph["cells"]:
					if W0["ents"].has(c):
						return {"ok": false}
		frames.append(clone(s))
		settle(s, frames)
		frames[frames.size() - 1] = s
		return {"ok": true, "state": s, "frames": frames}
	else:
		return {"ok": false}
	s["moves"] += 1
	frames.append(clone(s))
	settle(s, frames)
	frames[frames.size() - 1] = s
	return {"ok": true, "state": s, "frames": frames}

func is_win(s: Dictionary) -> bool:
	return not s["dead"] and s["p"] == goal

func find_path(s: Dictionary, target: Vector3i):
	var W := build_world(s)
	W["ents"].erase(s["p"])
	if s["p"] == target:
		return []
	var prev := {s["p"]: null}
	var q := [s["p"]]
	var head := 0
	while head < q.size():
		var P: Vector3i = q[head]
		head += 1
		for d in 4:
			var T = walk_target(s, W, P, d)
			if T == null or prev.has(T):
				continue
			prev[T] = {"from": P, "d": d}
			if T == target:
				var dirs := []
				var cur = T
				while prev[cur] != null:
					dirs.push_front(prev[cur]["d"])
					cur = prev[cur]["from"]
				return dirs
			q.append(T)
	return null
