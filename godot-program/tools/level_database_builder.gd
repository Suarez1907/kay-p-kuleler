## 100 seviyelik devre kampanyasını üretir ve doğrular → res://data/levels_100.json
##   godot --headless --path godot-program --script res://tools/level_database_builder.gd            (üret + yaz)
##   godot --headless --path godot-program --script res://tools/level_database_builder.gd -- --check (yalnızca doğrula)
## Her seviye önce çözüm planından kurulur: bir "kurucu" Robo'yu boş dünyada adım adım yürütür, bastığı yere
## SMD transistör, merdiven, diyot, kondansatör, röle + köprü, direnç yerleştirir ve komutları kaydeder. Komut
## listesi F1/F2'ye sıkıştırılır (kapasiteler dar). Aday, oyunun kendi tur tabanlı motorunda (Program.run_ticks)
## çalıştırılır; kazanmayan, mekaniği atlayarak da kazanılan (ör. klonsuz AND) adaylar atılır.
## Faz dağılımı: 1–2 SMD + temel hareket ve F1, 3–4 diyot, 5–6 kondansatör, 7–8 röle (OR, AND + klon),
## 9–10 direnç + hepsi; 100. seviye büyük final.
extends SceneTree

const DIRS := [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]
const UP := Vector3i(0, 1, 0)
const DOWN := Vector3i(0, -1, 0)
const OUT := "res://data/levels_100.json"

class B:
	var p := Vector3i(0, 1, 0)
	var d := 0
	var blocks := {}       # Vector3i -> true
	var empty := {}        # boş kalması gereken hücreler
	var stairs := []
	var cmds := []
	var comps := {}        # blok hücresi -> bileşen sözlüğü
	var bridges := []
	var path := []         # [{cell, in, out}]
	var failed := false
	var circuit_n := 0
	var clone_cmds := []   # klonun F1 satırı (AND seviyeleri)
	var nodiode := {}      # diyot konmayacak kareler (klonun ayrıldığı kavşak)

	func _init() -> void:
		solid(p + DOWN)
		keep(p)
		path.append({"cell": p, "in": -1, "out": -1})

	func solid(c: Vector3i) -> void:
		if empty.has(c):
			failed = true
		blocks[c] = true
	func keep(c: Vector3i) -> void:
		for q in [c, c + UP]:
			if blocks.has(q):
				failed = true
			empty[q] = true
	func hole(c: Vector3i) -> void:
		if blocks.has(c):
			failed = true
		empty[c] = true
	func is_free(c: Vector3i) -> bool:
		return not blocks.has(c) and not empty.has(c)
	func fwd() -> Vector3i:
		return DIRS[d]
	func _arrive(q: Vector3i, din: int) -> void:
		path[path.size() - 1]["out"] = din
		path.append({"cell": q, "in": din, "out": -1})
		p = q

	func F(n := 1) -> void:
		for i in n:
			var q := p + fwd()
			solid(q + DOWN)
			keep(q)
			cmds.append("F")
			_arrive(q, d)
	func turn(s: String) -> void:
		d = (d + (3 if s == "L" else 1)) % 4
		cmds.append(s)
		path[path.size() - 1]["out"] = -2     # dönülen kare diyot olamaz
	func up() -> void:
		var q := p + fwd()
		solid(q)
		solid(q + DOWN)
		stairs.append({"p": [q.x, q.y, q.z], "d": d})
		keep(q + UP)
		cmds.append("F")
		_arrive(q + UP, -3)
	func jump_up() -> void:
		var q := p + fwd()
		solid(q)
		solid(q + DOWN)
		keep(q + UP)
		cmds.append("J")
		_arrive(q + UP, -3)
	func jump_down() -> void:
		var q := p + fwd()
		hole(q)
		var r := q + DOWN
		solid(r + DOWN)
		keep(r)
		cmds.append("J")
		_arrive(r, -3)
	## kondansatör: üstüne basan Robo bir kare ileri ve boost kat yukarı fırlar
	func cap(boost := 1) -> void:
		var q := p + fwd()
		solid(q + DOWN)
		keep(q)
		var t := q + fwd() + UP * boost
		for k in boost:
			solid(q + fwd() + UP * k)
		solid(q + fwd() + DOWN)
		for k in range(1, boost + 1):
			hole(q + UP * k + UP)
		keep(t)
		comps[q + DOWN] = {"component_type": "CAPACITOR", "boost_height": boost}
		cmds.append("F")
		_arrive(q, -3)
		_arrive(t, -3)
	## direnç: üstünde delay tur beklenir
	func res(delay := 1) -> void:
		var q := p + fwd()
		solid(q + DOWN)
		keep(q)
		comps[q + DOWN] = {"component_type": "RESISTOR", "delay_turns": delay}
		cmds.append("F")
		_arrive(q, -3)
	## OR röle (yol üstünde): basınca önündeki köprü kalıcı olarak açılır
	func relay_or(gap := 1) -> void:
		circuit_n += 1
		var cid := "R%d" % circuit_n
		var q := p + fwd()
		solid(q + DOWN)
		keep(q)
		comps[q + DOWN] = {"component_type": "RELAY", "circuit_id": cid, "logic_mode": "OR"}
		cmds.append("F")
		_arrive(q, -3)
		_bridge_ahead(gap, cid)
	## OR röle yanda: Robo sapıp röleye basar, geri döner ve köprüden geçer
	func relay_side(gap := 1, side := "L") -> void:
		circuit_n += 1
		var cid := "R%d" % circuit_n
		var sd: Vector3i = DIRS[(d + (3 if side == "L" else 1)) % 4]
		var rc := p + sd
		if not is_free(rc) or not is_free(rc + DOWN):
			failed = true
		solid(rc + DOWN)
		keep(rc)
		comps[rc + DOWN] = {"component_type": "RELAY", "circuit_id": cid, "logic_mode": "OR"}
		var back := "R" if side == "L" else "L"
		var start := p
		turn(side)
		cmds.append("F")
		_arrive(rc, -3)
		turn(back)
		turn(back)
		cmds.append("F")
		_arrive(start, -3)
		turn(side)
		_bridge_ahead(gap, cid)
	## AND röle + klon: Robo burada klon bırakır; klon F1 ile yandaki röleye yürür, Robo önündeki röleye
	## basınca iki röle aynı anda basılı olur ve köprü açılır. extra: Robo'nun röleye kadar yürüdüğü kare sayısı
	func relay_and(clone_len := 2, side := "R", gap := 1, main_len := 2, main_res := 0) -> void:
		circuit_n += 1
		var cid := "A%d" % circuit_n
		cmds.append("C")
		nodiode[p] = true
		# klonun yolu (F1): yana dön, clone_len kare yürü; son kare röle
		var sdi: int = (d + (3 if side == "L" else 1)) % 4
		var cp := p
		clone_cmds = [side]
		for i in clone_len:
			cp = cp + DIRS[sdi]
			if not is_free(cp) or not is_free(cp + DOWN):
				failed = true
			solid(cp + DOWN)
			keep(cp)
			clone_cmds.append("F")
		comps[cp + DOWN] = {"component_type": "RELAY", "circuit_id": cid, "logic_mode": "AND"}
		# Robo'nun yolu: main_len kare (gerekirse direnç bekletir), son kare röle
		for i in main_len - 1:
			if i == 0 and main_res > 0:
				res(main_res)
			else:
				F(1)
		var q := p + fwd()
		solid(q + DOWN)
		keep(q)
		comps[q + DOWN] = {"component_type": "RELAY", "circuit_id": cid, "logic_mode": "AND"}
		cmds.append("F")
		_arrive(q, -3)
		_bridge_ahead(gap, cid)
	func _bridge_ahead(gap: int, cid: String) -> void:
		var cells := []
		for i in range(1, gap + 1):
			var c := p + fwd() * i + DOWN
			hole(c)
			cells.append([c.x, c.y, c.z])
		bridges.append({"cells": cells, "on": "C:" + cid})
		for i in gap:
			var q := p + fwd()
			keep(q)
			cmds.append("F")
			_arrive(q, -3)
		F(1)

	## Yolda tek yönde düz geçilen karelerin altını diyot yapar
	func diodes(rng: RandomNumberGenerator, n: int) -> void:
		var cand := []
		var seen := {}
		for e in path:
			seen[e["cell"]] = int(seen.get(e["cell"], 0)) + 1
		for i in range(1, path.size() - 1):
			var e: Dictionary = path[i]
			if e["in"] >= 0 and e["in"] == e["out"] and seen[e["cell"]] == 1 and not nodiode.has(e["cell"]) and not comps.has(e["cell"] + DOWN) and blocks.has(e["cell"] + DOWN):
				cand.append(e)
		for k in mini(n, cand.size()):
			var j := rng.randi_range(0, cand.size() - 1)
			var e2: Dictionary = cand[j]
			cand.remove_at(j)
			comps[e2["cell"] + DOWN] = {"component_type": "DIODE", "direction": e2["in"]}

	func to_def() -> Dictionary:
		var st := {}
		for s in stairs:
			st[Vector3i(s["p"][0], s["p"][1], s["p"][2])] = true
		var boxes := []
		for c in blocks:
			if st.has(c):
				continue
			boxes.append([c.x, c.y, c.z, c.x, c.y, c.z])
		var cl := []
		for c in comps:
			var e: Dictionary = comps[c].duplicate()
			e["p"] = [c.x, c.y, c.z]
			cl.append(e)
		var def := {"boxes": boxes, "stairs": stairs, "start": [0, 1, 0], "startDir": 0, "goal": [p.x, p.y, p.z]}
		if not cl.is_empty():
			def["comps"] = cl
		if not bridges.is_empty():
			def["bridges"] = bridges
		return def

# ---------------------------------------------------------------------------
# sıkıştırma
static func best_repeat(seq: Array, max_len: int) -> Dictionary:
	var best := {}
	for ln in range(2, max_len + 1):
		for i in range(0, seq.size() - ln + 1):
			var pat := seq.slice(i, i + ln)
			if "C" in pat:
				continue
			var occ := 0
			var j := 0
			while j + ln <= seq.size():
				if seq.slice(j, j + ln) == pat:
					occ += 1
					j += ln
				else:
					j += 1
			var save := occ * (ln - 1) - ln
			if occ >= 2 and save > 0 and (best.is_empty() or save > int(best["save"]) or (save == int(best["save"]) and ln > (best["pat"] as Array).size())):
				best = {"pat": pat, "save": save}
	return best

static func replace(seq: Array, pat: Array, sym: String) -> Array:
	var out := []
	var j := 0
	while j < seq.size():
		if j + pat.size() <= seq.size() and seq.slice(j, j + pat.size()) == pat:
			out.append(sym)
			j += pat.size()
		else:
			out.append(seq[j])
			j += 1
	return out

static func compress(cmds: Array, use_p1: bool, use_p2: bool) -> Dictionary:
	var main := cmds.duplicate()
	var p1 := []
	var p2 := []
	if use_p1:
		var b1 := best_repeat(main, 6)
		if not b1.is_empty():
			p1 = b1["pat"]
			main = replace(main, p1, "1")
	if use_p2:
		var b2 := best_repeat(main, 5)
		if not b2.is_empty():
			p2 = b2["pat"]
			main = replace(main, p2, "2")
	return {"main": main, "p1": p1, "p2": p2}

# ---------------------------------------------------------------------------
var levels := []
var report := []

func _init() -> void:
	var check := "--check" in OS.get_cmdline_user_args()
	if check:
		_check_file()
		return
	_generate()
	var ok := 0
	for d in levels:
		if _verify(d):
			ok += 1
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "phases": _phase_meta(), "levels": levels}, "", false))
	f.close()
	print("levels_100: %d/%d solvable → %s" % [ok, levels.size(), OUT])
	quit(0 if ok == 100 and levels.size() == 100 else 1)

func _check_file() -> void:
	var data = JSON.parse_string(FileAccess.open(OUT, FileAccess.READ).get_as_text())
	var ok := 0
	var lv: Array = data["levels"]
	for d in lv:
		if _verify(d):
			ok += 1
		else:
			print("ÇÖZÜMSÜZ: #%d %s" % [int(d["id"]), d["name"]])
	print("levels_100: %d/%d solvable" % [ok, lv.size()])
	quit(0 if ok == 100 and lv.size() == 100 else 1)

## Doğrulama: referans çözüm kazanmalı; klonlu seviyede C olmadan kazanılmamalı; sayılar tutarlı olmalı
func _verify(d: Dictionary) -> bool:
	var L := PuzzleLogic.new()
	L.load_level(d.duplicate(true))
	var sol: Dictionary = d["hint_solution"]
	var r := Program.run_ticks(L, sol, [])
	if r["result"] != "win":
		return false
	var prog := Program.parse_program(sol)
	for row in ["main", "p1", "p2"]:
		if prog[row].size() > int(d["slots"].get(row, 0)):
			return false
		for ins in prog[row]:
			if not (ins["c"] in d["cmds"]):
				return false
	if Program.block_count(prog) != int(d["par_commands"]):
		return false
	if d.get("enable_clone", false):
		var noclone := {"main": [], "p1": sol.get("p1", []), "p2": sol.get("p2", [])}
		for c in sol["main"]:
			if c != "C":
				noclone["main"].append(c)
		var L2 := PuzzleLogic.new()
		L2.load_level(d.duplicate(true))
		if Program.run_ticks(L2, noclone, [])["result"] == "win":
			return false
	return true

const PHASE_NAMES := ["Anakart (PCB) & Bakır Yollar", "Güç Kaynağı (PSU) & Voltaj Regülatörleri", "İşlemci (CPU) & Soket Mimarisi",
	"RAM Modülleri & Veri Yolları", "Depolama (NVMe SSD)", "Ekran Kartı (GPU) & VRAM", "Soğutma Sistemi",
	"Ses, Ağ ve I/O Portları", "Kasa, Kablolama ve Aydınlatma", "Monitör, Klavye ve Sistem Çekirdeği"]
const PHASE_SHORT := ["Anakart", "PSU", "CPU", "RAM", "Depolama", "GPU", "Soğutma", "I/O", "Kasa", "Sistem Çekirdeği"]
const PHASE_MECH := [["SMD_TRANSISTOR"], ["SMD_TRANSISTOR"], ["DIODE"], ["DIODE"], ["CAPACITOR"], ["CAPACITOR", "DIODE"],
	["RELAY_OR"], ["RELAY_AND", "CLONE"], ["RESISTOR"], ["SMD_TRANSISTOR", "DIODE", "CAPACITOR", "RESISTOR", "RELAY_OR", "RELAY_AND", "CLONE"]]

func _phase_meta() -> Array:
	var out := []
	for i in 10:
		out.append({"id": i + 1, "name": PHASE_SHORT[i], "hardware": PHASE_NAMES[i], "levels": [i * 10 + 1, i * 10 + 10], "mechanics": PHASE_MECH[i]})
	return out

const INTROS := {
	1: {"title": "Devre kartına hoş geldin", "text": "Her seviye bir bilgisayar parçası kazandırır. Zemin blokları <b>SMD transistörlerdir</b>: Robo üstlerinde güvenle yürür, bastığında bacaklarından enerji geçer. Programı yaz, <b>▶ Çalıştır</b>'a bas ve Robo'yu parlayan kristale ulaştır."},
	6: {"title": "Fonksiyon: F1", "text": "Tekrar eden bir deseni <b>F1</b> satırına yaz, ana programda <b>F1</b> bloğuyla çağır. Yer azaldıkça fonksiyonlar şart olacak."},
	21: {"title": "Diyot", "text": "Turuncu oklu <b>diyotlarda</b> akım tek yöne akar: Robo bir diyota yalnızca ok yönünde girip çıkabilir. Ters yönden girmeye çalışırsa kısa devre kıvılcımıyla geri seker."},
	31: {"title": "Diyot ve sensör", "text": "Koşullu bloklar (yeşil: önü açıksa, turuncu: önü kapalıysa) diyotları da algılar: ters yönlü bir diyot Robo için kapalı bir yoldur."},
	41: {"title": "Kondansatör", "text": "Mavi alüminyum <b>kondansatör</b> üstüne basan Robo'yu baktığı yönde bir kare ileri ve bir kat yukarı fırlatır. Zıplamana gerek yok!"},
	51: {"title": "Yüksek voltaj", "text": "Bazı kondansatörler daha güçlüdür: Robo'yu <b>iki kat</b> yukarı fırlatırlar. Diyotlarla birlikte enerji zincirleri kur."},
	61: {"title": "Röle (OR)", "text": "Şeffaf kapaklı <b>röleye</b> basınca bağlı olduğu devre kapanır ve uzaktaki köprü açılır (PCB'deki bakır iz parlar). OR devrede tek bir röle yeter."},
	71: {"title": "AND kapısı ve klon", "text": "AND devresinde <b>bütün</b> röleler aynı turda basılı olmalı. <b>Klon</b> bloğu Robo'nun yerine yarı saydam bir klon bırakır; klon <b>F1</b> satırını Robo ile aynı ritimde çalıştırır. Klonu bir röleye gönder, sen diğerine bas!"},
	81: {"title": "Direnç", "text": "Renk bantlı <b>direnç</b> Robo'yu üstünde bekletir (bantlar bekleme süresini gösterir: 1 ya da 2 tur). Klon ile Robo'yu aynı anda rölelere ulaştırmak için gecikmeyi kullan."},
	91: {"title": "Sistem çekirdeği", "text": "Son faz: beş devre elemanı, fonksiyonlar, klon ve lojik kapılar bir arada. Son parçayı takınca bilgisayarın açılışını izle!"},
}

func _generate() -> void:
	var lib := PCPartLibrary.all()
	for i in 100:
		var lv := i + 1
		var ph := i / 10
		var def := {}
		for attempt in 600:
			var rng := RandomNumberGenerator.new()
			rng.seed = lv * 7919 + attempt * 104729 + 17
			var b := B.new()
			var plan := _plan(lv, ph, i % 10, b, rng)
			if b.failed:
				continue
			var d := _finish(lv, ph, b, plan)
			if d.is_empty():
				continue
			if _verify(d):
				def = d
				break
		if def.is_empty():
			push_error("seviye üretilemedi: %d" % lv)
			def = {"id": lv, "name": "?", "hint_solution": {"main": []}, "slots": {}, "cmds": [], "par_commands": 0}
		levels.append(def)

## Seviye planı: faz ve faz içi sıraya göre parça dizisi. Dönüş: {use_p1, use_p2, conds, clone}
func _plan(lv: int, ph: int, k: int, b: B, r: RandomNumberGenerator) -> Dictionary:
	var plan := {"use_p1": lv >= 6, "use_p2": lv >= 14, "conds": false, "clone": false, "follower": []}
	match ph:
		0:
			if lv <= 2:
				b.F(2 + lv)
				if lv == 2:
					b.turn("R")
					b.F(2)
			elif lv <= 5:
				_walk(b, r, 2 + k, lv >= 4)
			else:
				# F1 deseni: kısa bir desen tekrarlanır
				var pat := []
				var n := 2 + (k % 3)
				for j in n:
					pat.append(["F", "F", "up", "L", "R"][r.randi_range(0, 4)])
				if not ("L" in pat or "R" in pat):
					pat.append("R" if r.randf() < 0.5 else "L")
				for rep in 3 + (k % 2):
					for c in pat:
						match c:
							"F": b.F(1)
							"up": b.up()
							_: b.turn(c)
		1:
			b.F(1)
			_walk(b, r, 4 + k / 2, true, true)
			var pat2 := ["F", "J", "R"] if r.randf() < 0.5 else ["F", "up", "L"]
			for rep in 3:
				for c in pat2:
					match c:
						"F": b.F(1)
						"J": b.jump_up()
						"up": b.up()
						_: b.turn(c)
			_walk(b, r, 1)
		2, 3:
			if ph == 3 and k >= 4:
				# diyotlu labirent + duvar izleyici
				plan["conds"] = true
				plan["follower"] = ["o:F", "x:R", "x:L", "x:L", "1"] if r.randf() < 0.5 else ["o:F", "x:L", "x:R", "x:R", "1"]
				var steps := 0
				while steps < 12 + k * 2:
					if steps > 0 and r.randf() < 0.45:
						b.turn("L" if r.randf() < 0.5 else "R")
					for j in r.randi_range(1, 3):
						if r.randf() < 0.15:
							b.up()
						else:
							b.F(1)
						steps += 1
				b.diodes(r, 3 + k / 3)
			else:
				b.F(1)
				_walk(b, r, 4 + k, true, ph == 3)
				b.diodes(r, 2 + k / 2 + (ph - 2) * 2)
		4, 5:
			b.F(1)
			var caps := 1 + k / 3 + (ph - 4)
			for c in caps:
				_walk(b, r, r.randi_range(1, 2), true, false)
				b.cap(2 if (ph == 5 and r.randf() < 0.5) else 1)
			_walk(b, r, 1)
			b.diodes(r, (ph - 4) * 2 + k / 4)
		6:
			b.F(1)
			for c in 1 + k / 4:
				_walk(b, r, r.randi_range(1, 2), true, false)
				if k >= 3 and r.randf() < 0.6:
					b.relay_side(r.randi_range(1, 2), "L" if r.randf() < 0.5 else "R")
				else:
					b.relay_or(r.randi_range(1, 2))
			_walk(b, r, 1)
			if k >= 5:
				b.cap(1)
			b.diodes(r, k / 3)
		7:
			plan["clone"] = true
			plan["use_p1"] = false
			b.F(r.randi_range(1, 2))
			_walk(b, r, r.randi_range(0, 1 + k / 3), true, false)
			var cl := r.randi_range(1, 2 + k / 4)
			# klon röleye cl+1 turda (dönüş + cl adım) varır; Robo en erken o turda kendi rölesine basmalı
			b.relay_and(cl, "L" if r.randf() < 0.5 else "R", r.randi_range(1, 2), cl + 1 + r.randi_range(0, 1), 0)
			_walk(b, r, 1 + k / 3)
			if k >= 6:
				b.cap(1)
			b.diodes(r, k / 3)
		8:
			b.F(1)
			for c in 1 + k / 3:
				_walk(b, r, r.randi_range(1, 2), true, false)
				b.res(1 + (c + k) % 2)
			if k >= 4:
				_walk(b, r, 1)
				b.relay_or(1)
			if k >= 7:
				b.cap(1)
			_walk(b, r, 1)
			b.diodes(r, 1 + k / 3)
		9:
			# her şey bir arada; son seviyeler AND + direnç senkronizasyonu
			b.F(1)
			_walk(b, r, r.randi_range(1, 2), true, true)
			b.cap(1 + (k % 2))
			_walk(b, r, 1)
			b.res(1 + k % 2)
			if k >= 2:
				plan["clone"] = true
				plan["use_p1"] = false
				var cl2 := r.randi_range(2, 3 + k / 4)
				# Robo röleye klondan önce ulaşacaksa direnç bekletir (senkronizasyon)
				# Robo klondan önce varacaksa yolundaki direnç onu bekletir (senkronizasyon)
				var wait := r.randi_range(1, 2)
				var ml := maxi(2, cl2 + 1 - wait)
				b.relay_and(cl2, "L" if r.randf() < 0.5 else "R", 1, ml, wait)
			_walk(b, r, 1)
			b.relay_or(1)
			_walk(b, r, 1 + k / 4)
			b.diodes(r, 2 + k / 3)
	return plan

func _walk(b: B, r: RandomNumberGenerator, n: int, stairs := true, jumps := false) -> void:
	for s in n:
		var x := r.randf()
		if x < 0.34:
			b.F(r.randi_range(1, 3))
		elif x < 0.62:
			b.turn("L" if r.randf() < 0.5 else "R")
			b.F(r.randi_range(1, 2))
		elif stairs and x < 0.8:
			b.up()
		elif jumps and x < 0.9:
			b.jump_up()
		else:
			b.F(1)

func _finish(lv: int, ph: int, b: B, plan: Dictionary) -> Dictionary:
	var d := b.to_def()
	var sol := {}
	if plan["follower"] is Array and not (plan["follower"] as Array).is_empty():
		sol = {"main": ["1"], "p1": plan["follower"]}
		d["conds"] = true
		d["slots"] = {"main": 2, "p1": (plan["follower"] as Array).size(), "p2": 0}
	else:
		var c := compress(b.cmds, plan["use_p1"], plan["use_p2"])
		sol = {"main": c["main"]}
		if plan["clone"]:
			sol["p1"] = b.clone_cmds
			if not (c["p2"] as Array).is_empty():
				sol["p2"] = c["p2"]
		else:
			if not (c["p1"] as Array).is_empty():
				sol["p1"] = c["p1"]
			if not (c["p2"] as Array).is_empty():
				sol["p2"] = c["p2"]
		var slack := 2 if lv <= 10 else 1
		d["slots"] = {"main": (sol["main"] as Array).size() + slack, "p1": (sol.get("p1", []) as Array).size(), "p2": (sol.get("p2", []) as Array).size()}
		if lv >= 6 and lv <= 10 and (sol.get("p1", []) as Array).is_empty():
			return {}
	var used := {"F": true, "L": true, "R": true}
	for row in ["main", "p1", "p2"]:
		for x in sol.get(row, []):
			var cc: String = x.split(":")[-1]
			used[cc] = true
	if plan["clone"]:
		used["C"] = true
		used["1"] = true
		d["enable_clone"] = true
	if d["slots"]["p1"] > 0:
		used["1"] = true
	var order := ["F", "L", "R", "J", "A", "C", "1", "2"]
	var cmds := []
	for o in order:
		if used.has(o):
			cmds.append(o)
	var part := PCPartLibrary.part(lv)
	d["id"] = lv
	d["name"] = part.part_name
	d["phase"] = ph + 1
	d["chapter"] = PHASE_SHORT[ph]
	d["phase_name"] = PHASE_NAMES[ph]
	d["palette"] = (lv * 3) % 16
	d["cmds"] = cmds
	d["hint_solution"] = sol
	d["solution"] = sol
	var pc := 0
	for row in ["main", "p1", "p2"]:
		pc += (sol.get(row, []) as Array).size()
	d["par_commands"] = pc
	d["par"] = pc
	if INTROS.has(lv):
		d["intro"] = INTROS[lv]
	d["hint"] = _hint(d)
	return d

func _hint(d: Dictionary) -> String:
	var parts := []
	var has := func(t: String) -> bool:
		for c in d.get("comps", []):
			if c.get("component_type", "") == t:
				return true
		return false
	if d.get("enable_clone", false):
		parts.append("Klonu bırak; klonun yolu F1'de. İki röle aynı turda basılı olmalı.")
	if has.call("DIODE"):
		parts.append("Diyotlara yalnızca ok yönünde gir.")
	if has.call("CAPACITOR"):
		parts.append("Kondansatör seni ileri ve yukarı fırlatır.")
	if has.call("RESISTOR"):
		parts.append("Direnç seni bekletir.")
	if has.call("RELAY") and not d.get("enable_clone", false):
		parts.append("Röleye basınca köprü açılır.")
	parts.append("Takılırsan ampule bas: sıradaki adımı gösteririm.")
	return " ".join(parts)
