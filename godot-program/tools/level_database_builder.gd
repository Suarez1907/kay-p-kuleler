## 100 seviyelik devre kampanyasını üretir ve doğrular → res://data/levels_100.json
##   godot --headless --path godot-program --script res://tools/level_database_builder.gd
##   godot --headless --path godot-program --script res://tools/level_database_builder.gd -- --check
## Her seviye elde kurulmuş bir rotadır (kopya rastgele yürüyüş yok). Motor (Program.run_ticks + PuzzleLogic)
## rotayı oynatır; par_commands, yuva sınırına sığan en kısa programdır (BFS + sınırlı program araması).
## Fazlar: 1–2 hareket / yükseklik / F1, 3–4 diyot, 5–6 kondansatör, 7–8 röle OR sonra AND+klon,
## 9–10 direnç zamanlaması ve final. F2 yok. Parça adları PCPartLibrary ile birebir (seviye N → parça N).
extends SceneTree

const DIRS := [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]
const UP := Vector3i(0, 1, 0)
const DOWN := Vector3i(0, -1, 0)
const OUT := "res://data/levels_100.json"

class B:
	var p := Vector3i(0, 1, 0)
	var d := 0
	var blocks := {}
	var empty := {}
	var stairs := []
	var cmds := []
	var comps := {}
	var bridges := []
	var path := []
	var failed := false
	var circuit_n := 0
	var clone_cmds := []
	var nodiode := {}

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
		path[path.size() - 1]["out"] = -2

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

	func res(delay := 1) -> void:
		var q := p + fwd()
		solid(q + DOWN)
		keep(q)
		comps[q + DOWN] = {"component_type": "RESISTOR", "delay_turns": delay}
		cmds.append("F")
		_arrive(q, -3)

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

	## AND: klon F1 ile yandaki röleye, Robo main_len adımda kendi rölesine. Aynı turda basılınca köprü açılır.
	## wait>0 ise Robo'nun ilk adımı dirençtir (klonla senkron). Köprünün uzak ucu hedeftir.
	func relay_and(clone_len := 1, side := "R", gap := 1, main_len := 2, main_res := 0) -> void:
		circuit_n += 1
		var cid := "A%d" % circuit_n
		cmds.append("C")
		nodiode[p] = true
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

	func mark_diode() -> void:
		var floor := p + DOWN
		if comps.has(floor) or not blocks.has(floor):
			failed = true
			return
		comps[floor] = {"component_type": "DIODE", "direction": d}

	## Yan koridor. trap: ilk kare girilir, ikincisi ters diyottur. Değilse giriş ters diyottur (görünür sahte yol).
	func stub(side: String, n: int, trap: bool) -> void:
		var sdi := (d + (3 if side == "L" else 1)) % 4
		var c := p
		for i in n:
			c = c + DIRS[sdi]
			if not is_free(c) or not is_free(c + DOWN):
				failed = true
				return
			solid(c + DOWN)
			keep(c)
			var block_i := 1 if trap else 0
			if i == block_i:
				comps[c + DOWN] = {"component_type": "DIODE", "direction": (sdi + 2) % 4}

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


const PHASE_NAMES := ["Anakart (PCB) & Bakır Yollar", "Güç Kaynağı (PSU) & Voltaj Regülatörleri", "İşlemci (CPU) & Soket Mimarisi",
	"RAM Modülleri & Veri Yolları", "Depolama (NVMe SSD)", "Ekran Kartı (GPU) & VRAM", "Soğutma Sistemi",
	"Ses, Ağ ve I/O Portları", "Kasa, Kablolama ve Aydınlatma", "Monitör, Klavye ve Sistem Çekirdeği"]
const PHASE_SHORT := ["Anakart", "PSU", "CPU", "RAM", "Depolama", "GPU", "Soğutma", "I/O", "Kasa", "Sistem Çekirdeği"]
const PHASE_MECH := [["SMD_TRANSISTOR"], ["SMD_TRANSISTOR"], ["DIODE"], ["DIODE"], ["CAPACITOR"], ["CAPACITOR", "DIODE"],
	["RELAY_OR"], ["RELAY_AND", "CLONE"], ["RESISTOR"], ["SMD_TRANSISTOR", "DIODE", "CAPACITOR", "RESISTOR", "RELAY_OR", "RELAY_AND", "CLONE"]]

const INTROS := {
	1: {"title": "Devre kartına hoş geldin", "text": "Her seviye bir bilgisayar parçası kazandırır. Zemin blokları <b>SMD transistörlerdir</b>: Robo üstlerinde güvenle yürür, bastığında bacaklarından enerji geçer. Programı yaz, <b>▶ Çalıştır</b>'a bas ve Robo'yu parlayan kristale ulaştır."},
	6: {"title": "Fonksiyon: F1", "text": "İki ileri adımı <b>F1</b> satırına yaz. Ana programda <b>F1</b>, sağa dön, <b>F1</b>, sağa dön, <b>F1</b>. Ana satır bütün adımları almaz: fonksiyonu kullanmadan program sığmaz."},
	12: {"title": "Zıpla", "text": "<b>Zıpla</b> düz bir bloğun üstüne çıkar ya da bir kat aşağı iner. Merdivenleri ileriyle çık; düz bloğu ancak zıplayarak aşarsın."},
	21: {"title": "Diyot", "text": "Turuncu oklu <b>diyotlarda</b> akım tek yöne akar: Robo bir diyota yalnızca ok yönünde girip çıkabilir. Ters yönden girmeye çalışırsa kısa devre kıvılcımıyla geri seker."},
	31: {"title": "Ters diyot", "text": "Kısa görünen yan koridor <b>ters diyotla</b> kapanır: ok sana bakıyorsa o kareye giremezsin. Kristal, ok yönündeki yoldadır. Fazladan dönüşe yuvarın yetmeyebilir."},
	41: {"title": "Kondansatör", "text": "Mavi alüminyum <b>kondansatör</b> üstüne basan Robo'yu baktığı yönde bir kare ileri ve bir kat yukarı fırlatır. Zıplamana gerek yok."},
	51: {"title": "Yüksek voltaj", "text": "Bazı kondansatörler daha güçlüdür: Robo'yu <b>iki kat</b> yukarı fırlatırlar. İndiğin yöndeki diyot hâlâ tek yönlüdür."},
	61: {"title": "Röle (OR)", "text": "Şeffaf kapaklı <b>röleye</b> basınca bağlı olduğu devre kapanır ve köprü açılır. OR devrede tek röle yeter. Köprüyü açmadan karşıya geçemezsin."},
	71: {"title": "AND kapısı ve klon", "text": "AND devresinde <b>bütün</b> röleler aynı turda basılı olmalı. <b>Klon</b> Robo'nun yerine yarı saydam bir kopya bırakır; kopya <b>F1</b> satırını Robo ile aynı ritimde çalıştırır. Klonu bir röleye gönder, sen diğerine bas."},
	81: {"title": "Direnç", "text": "Renk bantlı <b>direnç</b> Robo'yu üstünde bekletir. Bantlar süreyi gösterir: bir bant bir tur, iki bant iki tur. Beklerken programın ilerlemez."},
	87: {"title": "Dirençle senkron", "text": "Klon röleye senden önce varacaksa yoldaki <b>direnç</b> seni bekletir. İkiniz aynı turda basmazsanız AND köprüsü açılmaz. Kısa program yanlış zamanda varır."},
	91: {"title": "Sistem çekirdeği", "text": "Son on seviye: diyot, kondansatör, direnç, röle ve klon bir arada. Yüzüncü parçadan sonra bilgisayar açılır."},
}

func _specs() -> PackedStringArray:
	return PackedStringArray([
		"F F F", # 1 düz
		"F F R F F", # 2 köşe
		"F L F F F", # 3 diğer köşe
		"F U F F", # 4 ilk merdiven
		"F U R F U F", # 5 iki merdiven
		"fn F F R F F R F F", # 6 F1: (FFR)×2 + FF
		"fn F U L F U L F F", # 7 aynı ritim, merdiven
		"F F R F F L F F R F", # 8 zikzak
		"U R U R U R F F", # 9 kule
		"fn F F L F F L F R F", # 10 F1 sınavı
		"F U F", # 11
		"Ju F F", # 12 ilk zıplama
		"U U Jd F", # 13 in
		"F Ju R F F", # 14
		"Ju L F Ju F", # 15
		"fn F R F L F R F L F F", # 16 (FRFL)×2
		"U R F U R F U F", # 17
		"F Ju L Ju R F", # 18
		"F F R U F R F F", # 19
		"fn F U R F U R F L F F", # 20
		"F Fd F", # 21 tek diyot
		"F Fd F R F Fd F", # 22
		"F Fd F L F Fd F F", # 23
		"F Fd F R F Fd F R F Fd F", # 24 tek yön döngü
		"F Fd U F F", # 25 diyot + merdiven
		"fn Fd U R Fd F R F F", # 26 FFR ritmi, diyot ve merdiven
		"F Fd F L F Fd F R F Fd F", # 27
		"F Fd F L F Fd F L F F", # 28
		"F Fd F R F Fd F L F tR", # 29 sahte
		"Fd F L Fd F L F R F", # 30 diyotlu FFL, F1 yok (sağ-el kısayolu)
		"F F Fd F", # 31 sade tekrar
		"F Fd F R F Fd F tL", # 32
		"F Fd Fd F R F Fd F", # 33
		"F Fd U R F Fd F", # 34
		"fn F Fd F R F Fd F L F Fd F", # 35
		"F Fd F L F Fd F R Fd F", # 36 sol kıvrım
		"F Fd F L F Fd F tR", # 37
		"F Fd F R F Fd Fd F L F", # 38
		"F Fd Fd F L F Fd F tL", # 39
		"fn Fd F R Fd F R F F vL", # 40 FFR, sahte ters koridor
		"F C1 F", # 41 tek kondansatör
		"F F C1 F", # 42
		"C1 R F F", # 43
		"F C1 L F F", # 44
		"F C1 R F C1 F", # 45 iki fırlatma
		"C1 F L C1 F", # 46
		"F C1 R C1 L F", # 47
		"fn F C1 R F C1 R F F", # 48 F1, F artık fırlatır
		"F F C1 R F F", # 49
		"F C1 L F C1 R F", # 50
		"F C2 F", # 51 iki kat
		"F C2 F F", # 52
		"F C2 R F Fd F", # 53
		"C2 L F Fd F", # 54
		"F Fd C2 F", # 55
		"F C1 R F C2 F", # 56 alçak / yüksek
		"F Fd C2 R F Fd F", # 57
		"F C2 L F Fd F R F", # 58
		"F Fd C2 R F C1 F", # 59
		"F C2 Fd F L F C1 R F Fd F tL", # 60
		"F O1", # 61 röle, hedef köprüde
		"O2", # 62 uzun köprü
		"F SL", # 63 yandaki röle
		"SR", # 64
		"F O1 R F F", # 65
		"F SL F", # 66
		"F Fd F O1", # 67
		"F Fd O1 L F", # 68 diyot, sonra OR ve dönüş
		"F O2 tR", # 69
		"F Fd F SL", # 70
		"AL1", # 71 AND, bir adımlık klon
		"AR1", # 72 ayna
		"F AL1", # 73
		"F AR2", # 74
		"F F AL1", # 75
		"F Fd F AL1", # 76
		"F AL2", # 77
		"F F AR2", # 78
		"F Fd F AL2", # 79
		"F Fd F AR2", # 80
		"F S1 F", # 81 direnç
		"F S2 F", # 82
		"F S1 F S1 F", # 83
		"F S1 R F F", # 84
		"F S1 Fd F", # 85
		"F S2 C1 F", # 86
		"F AL2w1", # 87 senkron
		"F AR3w2", # 88
		"F Fd S1 AL2w1", # 89
		"F Fd F AR2w1 tL", # 90
		"fn Fd U R Fd F R S1 F", # 91 FFR + direnç
		"F S1 O1", # 92
		"F C1 SR", # 93
		"F Fd F AR1", # 94 diyottan çık, kısa sağ klon
		"F C2 O1", # 95
		"F Fd C1 F R F Fd F", # 96
		"F S1 C1 Fd F", # 97
		"F Fd F S1 AR3w1", # 98
		"F C2 F Fd F SL", # 99
		"F Fd F C1 S1 O1 AL2w1", # 100 final
	])


func _slack(lv: int) -> int:
	if lv == 6 or lv == 21 or lv == 41 or lv == 51 or lv == 61 or lv == 71 or lv == 81 or lv == 91:
		return 2
	var k := (lv - 1) % 10
	if k <= 1:
		return 2
	if k <= 4:
		return 1
	return 0


func _token(b: B, tok: String) -> void:
	if tok == "L" or tok == "R":
		b.turn(tok)
	elif tok == "U":
		b.up()
	elif tok == "Ju":
		b.jump_up()
	elif tok == "Jd":
		b.jump_down()
	elif tok.begins_with("F"):
		var diode := tok.ends_with("d")
		var mid := tok.substr(1)
		if diode:
			mid = mid.substr(0, mid.length() - 1)
		var n := 1 if mid == "" else int(mid)
		for i in n:
			if b.failed:
				return
			b.F(1)
			if diode:
				b.mark_diode()
	elif tok.begins_with("C") and tok.length() > 1 and tok.substr(1, 1).is_valid_int():
		b.cap(int(tok.substr(1)))
	elif tok.begins_with("S") and tok.length() > 1 and tok.substr(1, 1).is_valid_int():
		b.res(int(tok.substr(1)))
	elif tok.begins_with("SL") or tok.begins_with("SR"):
		var side := "L" if tok.begins_with("SL") else "R"
		var gap := 1 if tok.length() <= 2 else int(tok.substr(2))
		b.relay_side(gap, side)
	elif tok.begins_with("O"):
		b.relay_or(int(tok.substr(1)))
	elif tok.begins_with("A") and (tok.substr(1, 1) == "L" or tok.substr(1, 1) == "R"):
		var side2 := tok.substr(1, 1)
		var rest := tok.substr(2)
		var wi := rest.find("w")
		var clen := int(rest.substr(0, wi)) if wi >= 0 else int(rest)
		var wait := int(rest.substr(wi + 1)) if wi >= 0 else 0
		var main_len := clen + 1 - wait
		if clen < 1 or main_len < 2 or wait < 0:
			b.failed = true
			return
		b.relay_and(clen, side2, 1, main_len, wait)
	elif tok.begins_with("v") or tok.begins_with("t"):
		var trap := tok.begins_with("t")
		var side3 := tok.substr(1, 1)
		if side3 != "L" and side3 != "R":
			b.failed = true
			return
		var sn := 2 if trap else 1
		if tok.length() > 2:
			sn = int(tok.substr(2))
		b.stub(side3, sn, trap)
	else:
		b.failed = true


func _build(spec: String) -> Dictionary:
	var want_fn := spec.begins_with("fn ")
	var body := spec.substr(3) if want_fn else spec
	var b := B.new()
	var bad := ""
	for tok in body.split(" "):
		if tok == "":
			continue
		var was := b.failed
		_token(b, tok)
		if b.failed and not was:
			bad = tok
			break
	return {"b": b, "fn": want_fn, "bad": bad, "spec": body}


func _eq_at(seq: Array, i: int, pat: Array) -> bool:
	for k in pat.size():
		if String(seq[i + k]) != String(pat[k]):
			return false
	return true


## Tek F1, özyinelemesiz, örtüşmesiz en kısa kodlama. Tasarruf yoksa p1 boş.
func _min_encode(seq: Array) -> Dictionary:
	var n := seq.size()
	var best_cost := n
	var best := {"main": seq.duplicate(), "p1": [], "cost": n}
	for lp in range(1, mini(6, n) + 1):
		var seen := {}
		for i in range(0, n - lp + 1):
			var pat: Array = seq.slice(i, i + lp)
			var pk := "|".join(PackedStringArray(pat))
			if seen.has(pk):
				continue
			seen[pk] = true
			var dp: Array = []
			var prev: Array = []
			var kind: Array = []
			dp.resize(n + 1)
			prev.resize(n + 1)
			kind.resize(n + 1)
			for t in n + 1:
				dp[t] = 1 << 20
				prev[t] = -1
				kind[t] = 0
			dp[0] = 0
			for a in n:
				if int(dp[a]) + 1 < int(dp[a + 1]):
					dp[a + 1] = int(dp[a]) + 1
					prev[a + 1] = a
					kind[a + 1] = 0
				if a + lp <= n and _eq_at(seq, a, pat) and int(dp[a]) + 1 < int(dp[a + lp]):
					dp[a + lp] = int(dp[a]) + 1
					prev[a + lp] = a
					kind[a + lp] = 1
			var uses := 0
			var cur := n
			var rev: Array = []
			var guard := 0
			while cur > 0 and guard < 80:
				guard += 1
				var pv := int(prev[cur])
				if pv < 0:
					break
				if int(kind[cur]) == 1:
					uses += 1
					rev.append("1")
				else:
					rev.append(String(seq[pv]))
				cur = pv
			if cur != 0 or uses < 2:
				continue
			var cost := lp + int(dp[n])
			if cost < best_cost:
				best_cost = cost
				rev.reverse()
				best = {"main": rev, "p1": pat.duplicate(), "cost": cost}
	return best


func _state_key(s: Dictionary) -> String:
	return "%s|%d|%s|%s" % [s["p"], int(s["f"]), str(s.get("bridges", [])), str(s.get("circuits", {}))]


## Klonuz en kısa ilkel komut dizisi. Ulaşılamazsa dist -1.
func _bfs(L: PuzzleLogic, alpha: Array) -> Dictionary:
	var start := L.initial_state()
	var q: Array = [start]
	var dist := {_state_key(start): 0}
	var parent := {}
	var head := 0
	var goal_key := ""
	var goal_dist := -1
	while head < q.size():
		if q.size() > 8000:
			return {"dist": -1, "trace": [], "overflow": true}
		var s: Dictionary = q[head]
		head += 1
		var k := _state_key(s)
		var nd := int(dist[k])
		if goal_dist >= 0 and nd > goal_dist:
			break
		if s["p"] == L.goal and not s["dead"]:
			goal_dist = nd
			goal_key = k
			break
		if s["dead"]:
			continue
		for c in alpha:
			var r: Dictionary = Program.cmd_step(L, s, String(c))
			if r["bump"] or r["state"]["dead"]:
				continue
			var s2: Dictionary = r["state"]
			var k2 := _state_key(s2)
			if dist.has(k2):
				continue
			dist[k2] = nd + 1
			parent[k2] = {"k": k, "c": String(c)}
			q.append(s2)
	if goal_dist < 0:
		return {"dist": -1, "trace": [], "overflow": false}
	var trace: Array = []
	var ck := goal_key
	while parent.has(ck):
		trace.append(parent[ck]["c"])
		ck = parent[ck]["k"]
	trace.reverse()
	return {"dist": goal_dist, "trace": trace, "overflow": false}


func _products(n: int, alpha: Array) -> Array:
	if n <= 0:
		return [[]]
	var base := alpha.size()
	var total := 1
	for i in n:
		total *= base
	var out: Array = []
	out.resize(total)
	for t in total:
		var seq: Array = []
		seq.resize(n)
		var x := t
		for i in n:
			seq[i] = alpha[x % base]
			x = int(x / float(base))
		out[t] = seq
	return out


func _has(seq: Array, c: String) -> bool:
	return c in seq


func _prim(seq: Array) -> bool:
	for c in seq:
		if String(c) != "1":
			return true
	return false


## Klon turu: p1 sabitken en kısa ana programı durum aramasıyla bulur. "1" klon paletinde yoktur.
func _step_one(L: PuzzleLogic, s0: Dictionary, p1: Array, cpc: int, cmd: String) -> Dictionary:
	var s := PuzzleLogic.clone(s0)
	var cl: Dictionary = s.get("clone", {})
	if not cl.is_empty():
		if int(cl.get("wait", 0)) > 0:
			s["clone"]["wait"] = int(cl["wait"]) - 1
		elif cpc < p1.size():
			var cc := String(p1[cpc])
			cpc += 1
			if cc != "C" and cc != "W" and cc != "1":
				var cv := Program._as_clone(s)
				var r2: Dictionary = Program.cmd_step(L, cv, cc)
				if not r2["bump"]:
					s = Program._from_clone(r2["state"])
	if int(s.get("wait", 0)) > 0:
		s["wait"] = int(s["wait"]) - 1
		return {"state": s, "cpc": cpc, "ate": false}
	var r: Dictionary = Program.cmd_step(L, s, cmd)
	if cmd == "C":
		cpc = 0
	return {"state": r["state"], "cpc": cpc, "ate": true}


func _play(L: PuzzleLogic, s0: Dictionary, p1: Array, cpc: int, cmd: String) -> Dictionary:
	var s := s0
	var guard := 0
	while guard < 12:
		guard += 1
		var stepped := _step_one(L, s, p1, cpc, cmd)
		s = stepped["state"]
		cpc = int(stepped["cpc"])
		if L.is_win(s):
			return {"state": s, "cpc": cpc, "win": true, "dead": false}
		if s["dead"]:
			return {"state": s, "cpc": cpc, "win": false, "dead": true}
		if bool(stepped["ate"]):
			return {"state": s, "cpc": cpc, "win": false, "dead": false}
	return {"state": s, "cpc": cpc, "win": false, "dead": true}


func _replay(L: PuzzleLogic, main: Array, p1: Array) -> bool:
	var s := L.initial_state()
	var cpc := 0
	for cmd in main:
		var r := _play(L, s, p1, cpc, String(cmd))
		s = r["state"]
		cpc = int(r["cpc"])
		if r["win"]:
			return true
		if r["dead"]:
			return false
	return L.is_win(s)


func _cheaper_clone(L: PuzzleLogic, slots: Dictionary, alpha: Array, cost: int, p1_sol: Array) -> Dictionary:
	var max_m := int(slots["main"])
	var max_p := mini(int(slots["p1"]), 4)
	var sims := 0
	for pm in range(0, max_p + 1):
		var room := cost - 1 - pm
		if room < 1:
			continue
		var cap_m := mini(max_m, room)
		for p1 in _products(pm, alpha):
			if pm > 0 and not _prim(p1):
				continue
			sims += 1
			var start := L.initial_state()
			var q: Array = [{"s": start, "cpc": 0, "n": 0}]
			var seen := {_state_key(start) + "|0": 0}
			var head := 0
			while head < q.size():
				if q.size() > 20000:
					return {"found": false, "sims": sims, "overflow": true}
				var node: Dictionary = q[head]
				head += 1
				var n := int(node["n"])
				if n >= cap_m:
					continue
				var st: Dictionary = node["s"]
				if st["dead"]:
					continue
				var cpc := int(node["cpc"])
				for cmd in alpha:
					var r := _play(L, st, p1, cpc, String(cmd))
					var ns: Dictionary = r["state"]
					var nc := int(r["cpc"])
					var nn := n + 1
					if r["win"] and nn + pm < cost:
						return {"found": true, "sims": sims, "cost": nn + pm, "main": [], "p1": p1}
					if r["dead"] or ns["dead"]:
						continue
					var key := _state_key(ns) + "|" + str(nc)
					if seen.has(key) and int(seen[key]) <= nn:
						continue
					seen[key] = nn
					q.append({"s": ns, "cpc": nc, "n": nn})
	return {"found": false, "sims": sims}


## slots içine sığan, cost'tan kısa bir kazanan var mı? (F1 seviyeleri; klon ayrı aranır)
func _cheaper(L: PuzzleLogic, slots: Dictionary, alpha: Array, cost: int, clone: bool) -> Dictionary:
	var max_m := int(slots["main"])
	var max_p := int(slots["p1"])
	var sims := 0
	for b in range(1, cost):
		for pm in range(0, mini(b, max_p) + 1):
			var mm := b - pm
			if mm > max_m:
				continue
			var mains := _products(mm, alpha)
			var p1s := _products(pm, alpha) if pm > 0 else [[]]
			for main in mains:
				if clone and not _has(main, "C"):
					continue
				var calls := _has(main, "1")
				if not clone and not calls:
					if pm != 0:
						continue
					sims += 1
					if String(Program.run_ticks(L, {"main": main}, [])["result"]) == "win":
						return {"found": true, "main": main, "p1": [], "sims": sims, "cost": b}
					continue
				if not clone and pm == 0:
					continue
				for p1 in p1s:
					if pm > 0 and not _prim(p1):
						continue
					sims += 1
					if sims > 250000:
						return {"found": false, "sims": sims, "overflow": true}
					var src := {"main": main}
					if pm > 0:
						src["p1"] = p1
					if String(Program.run_ticks(L, src, [])["result"]) == "win":
						return {"found": true, "main": main, "p1": p1 if pm > 0 else [], "sims": sims, "cost": b}
	return {"found": false, "sims": sims}


func _hint_text(d: Dictionary) -> String:
	var parts: PackedStringArray = []
	var has := func(t: String) -> bool:
		for c in d.get("comps", []):
			if String(c.get("component_type", "")) == t:
				return true
		return false
	if d.get("enable_clone", false):
		parts.append("Klonu bırak; klonun yolu F1'de. İki röle aynı turda basılı olmalı.")
	if has.call("DIODE"):
		parts.append("Diyotlara yalnızca ok yönünde gir; ters ok sahte yoldur.")
	if has.call("CAPACITOR"):
		parts.append("Kondansatör seni ileri ve yukarı fırlatır.")
	if has.call("RESISTOR"):
		parts.append("Direnç seni bekletir; AND için zamanı buna göre kur.")
	if has.call("RELAY") and not d.get("enable_clone", false):
		parts.append("Röleye basınca köprü açılır.")
	if int(d["slots"]["p1"]) > 0 and not d.get("enable_clone", false):
		parts.append("Tekrar eden deseni F1'e yaz. Ana satır desenin tamamını almaz.")
	parts.append("Takılırsan ampule bas: sıradaki adımı gösteririm.")
	return " ".join(parts)


func _comp_counts(d: Dictionary) -> Dictionary:
	var n := {"DIODE": 0, "CAPACITOR": 0, "RESISTOR": 0, "RELAY": 0, "OR": 0, "AND": 0, "BOOST2": 0}
	for c in d.get("comps", []):
		var t := String(c.get("component_type", ""))
		if n.has(t):
			n[t] += 1
		if t == "RELAY":
			var m := String(c.get("logic_mode", ""))
			if m == "OR" or m == "AND":
				n[m] += 1
		if t == "CAPACITOR" and int(c.get("boost_height", 1)) >= 2:
			n["BOOST2"] += 1
	return n


func _supported(d: Dictionary, floor: Vector3i) -> bool:
	for b in d.get("boxes", []):
		if int(b[0]) == floor.x and int(b[1]) == floor.y and int(b[2]) == floor.z:
			return true
	for s in d.get("stairs", []):
		var p: Array = s["p"]
		if int(p[0]) == floor.x and int(p[1]) == floor.y and int(p[2]) == floor.z:
			return true
	for br in d.get("bridges", []):
		for c in br["cells"]:
			if int(c[0]) == floor.x and int(c[1]) == floor.y and int(c[2]) == floor.z:
				return true
	return false


func _geom_key(d: Dictionary) -> String:
	var boxes: Array = (d["boxes"] as Array).duplicate()
	boxes.sort_custom(func(a, b): return JSON.stringify(a) < JSON.stringify(b))
	var comps: Array = (d.get("comps", []) as Array).duplicate()
	comps.sort_custom(func(a, b): return JSON.stringify(a) < JSON.stringify(b))
	return JSON.stringify({"b": boxes, "s": d.get("stairs", []), "c": comps, "g": d["goal"], "r": d.get("bridges", [])})


func _links_ok(d: Dictionary) -> String:
	var relays := {}
	for c in d.get("comps", []):
		if String(c.get("component_type", "")) != "RELAY":
			continue
		var id := String(c.get("circuit_id", ""))
		var mode := String(c.get("logic_mode", ""))
		if id == "" or (mode != "OR" and mode != "AND"):
			return "röle kimliği/modu"
		if not relays.has(id):
			relays[id] = {"mode": mode, "n": 0}
		if String(relays[id]["mode"]) != mode:
			return "aynı devrede iki mod"
		relays[id]["n"] = int(relays[id]["n"]) + 1
	var seen_bridge := {}
	for br in d.get("bridges", []):
		var on := String(br.get("on", ""))
		if not on.begins_with("C:"):
			return "köprü bağı"
		var id2 := on.substr(2)
		if not relays.has(id2):
			return "köprünün rölesi yok: " + id2
		if (br.get("cells", []) as Array).is_empty():
			return "boş köprü"
		seen_bridge[id2] = true
	for id3 in relays:
		if not seen_bridge.has(id3):
			return "rölenin köprüsü yok: " + id3
		var nn := int(relays[id3]["n"])
		if String(relays[id3]["mode"]) == "AND" and nn < 2:
			return "AND tek röle"
		if String(relays[id3]["mode"]) == "OR" and nn < 1:
			return "OR rölesiz"
	return ""


func _finish_level(lv: int, built: Dictionary) -> Dictionary:
	var b: B = built["b"]
	var ph := (lv - 1) / 10
	if built["bad"] != "":
		push_error("#%d kurulamadı (%s) %s" % [lv, built["bad"], built["spec"]])
		return {}
	if b.failed or b.cmds.is_empty():
		push_error("#%d kurucu başarısız %s" % [lv, built["spec"]])
		return {}
	var trace: Array = b.cmds.duplicate()
	var clone: bool = not b.clone_cmds.is_empty()
	var enc := {"main": trace, "p1": [], "cost": trace.size()}
	if clone:
		enc = {"main": trace, "p1": b.clone_cmds.duplicate(), "cost": trace.size() + b.clone_cmds.size()}
	elif built["fn"]:
		enc = _min_encode(trace)
		if (enc["p1"] as Array).is_empty() or int(enc["cost"]) >= trace.size():
			push_error("#%d F1 deseni sıkışmıyor: %s" % [lv, " ".join(PackedStringArray(trace))])
			return {}
	var d := b.to_def()
	var sol := {"main": enc["main"]}
	if not (enc["p1"] as Array).is_empty():
		sol["p1"] = enc["p1"]
	var slack := _slack(lv)
	var slots := {"main": (enc["main"] as Array).size() + slack, "p1": (enc["p1"] as Array).size(), "p2": 0}
	if built["fn"]:
		var cap := trace.size() - 1
		if int(slots["main"]) > cap:
			slots["main"] = cap
		if int(slots["main"]) < (enc["main"] as Array).size():
			push_error("#%d F1 sığmıyor" % lv)
			return {}
	var used := {"F": true, "L": true, "R": true}
	for row in ["main", "p1"]:
		for x in sol.get(row, []):
			used[String(x)] = true
	if clone:
		used["C"] = true
		d["enable_clone"] = true
	var order := ["F", "L", "R", "J", "C", "1"]
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
	d["slots"] = slots
	d["hint_solution"] = sol
	d["solution"] = sol.duplicate(true)
	d["par_commands"] = int(enc["cost"])
	d["par"] = int(enc["cost"])
	if INTROS.has(lv):
		d["intro"] = INTROS[lv]
	d["hint"] = _hint_text(d)
	var L := PuzzleLogic.new()
	L.load_level(d.duplicate(true))
	var ran := Program.run_ticks(L, sol, [])
	if String(ran["result"]) != "win":
		push_error("#%d çözüm kazanmıyor (%s) %s" % [lv, ran["result"], built["spec"]])
		return {}
	var prims := ["F", "L", "R"]
	if "J" in cmds:
		prims.append("J")
	var bfs := _bfs(L, prims)
	if bfs.get("overflow", false):
		push_error("#%d BFS taştı" % lv)
		return {}
	if clone:
		if int(bfs["dist"]) >= 0:
			push_error("#%d klonsuz da çözülüyor (bfs %d)" % [lv, int(bfs["dist"])])
			return {}
		var stripped := {"main": [], "p1": sol.get("p1", [])}
		for c in sol["main"]:
			if c != "C":
				stripped["main"].append(c)
		if String(Program.run_ticks(L, stripped, [])["result"]) == "win":
			push_error("#%d C silinince kazanıyor" % lv)
			return {}
	else:
		if int(bfs["dist"]) != trace.size():
			push_error("#%d rota en kısa değil (iz %d, bfs %s) kurucu=%s bfs=%s" % [lv, trace.size(), str(bfs["dist"]), " ".join(PackedStringArray(trace)), " ".join(PackedStringArray(bfs["trace"]))])
			return {}
		if int(ran.get("steps", -1)) != trace.size():
			push_error("#%d yürütme adımı %s, iz %d" % [lv, str(ran.get("steps", -1)), trace.size()])
			return {}
	# F1 ya da klon yoksa her blok bir ilkel komuttur; BFS uzunluğu par'ın kendisidir.
	if clone or built["fn"]:
		if clone and not _replay(L, enc["main"], enc["p1"]):
			push_error("#%d klon adımlayıcı çözümle uyuşmuyor" % lv)
			return {}
		var cheap := _cheaper_clone(L, slots, cmds, int(enc["cost"]), enc["p1"]) if clone else _cheaper(L, slots, cmds, int(enc["cost"]), false)
		if cheap.get("overflow", false):
			push_error("#%d arama çok büyük (%d)" % [lv, int(cheap["sims"])])
			return {}
		if cheap.get("found", false):
			var prog := Program.parse_program({"main": cheap["main"], "p1": cheap.get("p1", [])})
			var ctx := {"prog": prog, "main": Program.Runner.new(prog), "clone": null, "gen": -1}
			var st := L.initial_state()
			var pos := PackedStringArray()
			for step_i in 14:
				pos.append("%s:%d" % [st["p"], int(st["f"])])
				if L.is_win(st):
					break
				var tk: Dictionary = Program.tick(L, st, ctx)
				st = tk["state"]
				if bool(tk.get("ended", false)) or st["dead"]:
					pos.append("end " + String(tk.get("reason", "")))
					break
			var cells := PackedStringArray()
			for bx in d["boxes"]:
				cells.append("%d,%d,%d" % [int(bx[0]), int(bx[1]) + 1, int(bx[2])])
			push_error("#%d daha kısa program %d (bizim %d) main=%s p1=%s goal=%s iz=%s hücre=%s" % [lv, int(cheap["cost"]), int(enc["cost"]), str(cheap["main"]), str(cheap.get("p1", [])), str(L.goal), " ".join(pos), " ".join(cells)])
			return {}
		d["sims"] = int(cheap.get("sims", 0))
	return d


func _phase_problems(levels: Array) -> PackedStringArray:
	var p := PackedStringArray()
	var stairs1 := 0
	var jumps2 := 0
	var fn1 := 0
	var boost2 := 0
	for d in levels:
		var id := int(d["id"])
		var c: Dictionary = _comp_counts(d)
		var fn: bool = int(d["slots"]["p1"]) > 0 and not bool(d.get("enable_clone", false))
		if id <= 20 and c["DIODE"] + c["CAPACITOR"] + c["RESISTOR"] + c["RELAY"] > 0:
			p.append("%d erken bileşen" % id)
		if id <= 10 and not (d.get("stairs", []) as Array).is_empty():
			stairs1 += 1
		if id >= 6 and id <= 20 and fn:
			fn1 += 1
		if id >= 11 and id <= 20 and "J" in d["cmds"]:
			jumps2 += 1
		if id >= 21 and id <= 40:
			if c["DIODE"] < 1:
				p.append("%d diyotsuz" % id)
			if c["CAPACITOR"] + c["RESISTOR"] + c["RELAY"] > 0:
				p.append("%d diyot fazında fazla bileşen" % id)
		if id >= 32 and id <= 40 and c["DIODE"] < 2:
			p.append("%d sahte/ters diyot yok" % id)
		if id >= 41 and id <= 60:
			if c["CAPACITOR"] < 1:
				p.append("%d kondansatörsüz" % id)
			if c["RESISTOR"] + c["RELAY"] > 0:
				p.append("%d kondansatör fazında röle/direnç" % id)
		if id >= 41 and id <= 50 and c["DIODE"] > 0:
			p.append("%d kondansatör dersinde diyot" % id)
		if id >= 51 and id <= 60:
			boost2 += c["BOOST2"]
			if id >= 53 and id != 56 and c["DIODE"] < 1:
				p.append("%d yüksek faz diyotsuz" % id)
		if id >= 61 and id <= 70:
			if c["OR"] < 1 or c["AND"] > 0 or d.get("enable_clone", false):
				p.append("%d OR röle değil" % id)
			if c["CAPACITOR"] + c["RESISTOR"] > 0:
				p.append("%d OR fazında fazla" % id)
		if id >= 71 and id <= 80:
			if c["AND"] < 2 or not d.get("enable_clone", false) or c["RESISTOR"] > 0:
				p.append("%d AND/klon değil" % id)
		if id >= 81 and id <= 86:
			if c["RESISTOR"] < 1 or c["RELAY"] > 0:
				p.append("%d sade direnç değil" % id)
		if id >= 87 and id <= 90:
			if c["RESISTOR"] < 1 or c["AND"] < 2 or not d.get("enable_clone", false):
				p.append("%d direnç senkronu değil" % id)
		if id >= 92 and id <= 99:
			var kinds := 0
			for t in ["DIODE", "CAPACITOR", "RESISTOR", "RELAY"]:
				if c[t] > 0:
					kinds += 1
			if kinds < 2:
				p.append("%d bileşik değil" % id)
		if id == 100:
			for t2 in ["DIODE", "CAPACITOR", "RESISTOR"]:
				if c[t2] < 1:
					p.append("100 eksik " + t2)
			if c["OR"] < 1 or c["AND"] < 2 or not d.get("enable_clone", false):
				p.append("100 final röle/klon eksik")
		if id == 21 and c["DIODE"] != 1:
			p.append("21 tek diyot olmalı")
		if id == 41 and c["CAPACITOR"] != 1:
			p.append("41 tek kondansatör olmalı")
		if id == 51 and c["BOOST2"] < 1:
			p.append("51 iki kat olmalı")
		if id == 61 and c["OR"] != 1:
			p.append("61 tek OR olmalı")
		if id == 81 and c["RESISTOR"] != 1:
			p.append("81 tek direnç olmalı")
	if stairs1 < 3:
		p.append("faz 1 merdiven az")
	if jumps2 < 2:
		p.append("faz 2 zıplama az")
	if fn1 < 4:
		p.append("faz 1-2 F1 az")
	if boost2 < 1:
		p.append("faz 6 iki kat yok")
	return p


func _structural(levels: Array) -> PackedStringArray:
	var p := PackedStringArray()
	if levels.size() != 100:
		p.append("seviye sayısı %d" % levels.size())
		return p
	var seen := {}
	var names := {}
	for i in levels.size():
		var d: Dictionary = levels[i]
		var id := int(d.get("id", -1))
		if id != i + 1:
			p.append("kimlik %d" % id)
			continue
		if String(d.get("name", "")) != PCPartLibrary.part(id).part_name:
			p.append("%d parça adı" % id)
		var g: Array = d["goal"]
		if int(d["start"][0]) != 0 or int(d["start"][1]) != 1 or int(d["start"][2]) != 0:
			p.append("%d başlangıç" % id)
		if int(g[0]) == 0 and int(g[1]) == 1 and int(g[2]) == 0:
			p.append("%d hedef başlangıç" % id)
		var goal := Vector3i(int(g[0]), int(g[1]), int(g[2]))
		if not _supported(d, goal + DOWN):
			p.append("%d hedefin zemini yok" % id)
		if not _supported(d, Vector3i(0, 0, 0)):
			p.append("%d başlangıç zemini yok" % id)
		var link := _links_ok(d)
		if link != "":
			p.append("%d %s" % [id, link])
		var sol: Dictionary = d["hint_solution"]
		if JSON.stringify(sol) != JSON.stringify(d["solution"]):
			p.append("%d hint/solution" % id)
		var prog := Program.parse_program(sol)
		if Program.block_count(prog) != int(d["par_commands"]) or int(d["par"]) != int(d["par_commands"]):
			p.append("%d par tutmuyor" % id)
		for row in ["main", "p1", "p2"]:
			if prog[row].size() > int(d["slots"].get(row, 0)):
				p.append("%d yuva %s" % [id, row])
			for ins in prog[row]:
				if not (String(ins["c"]) in d["cmds"]):
					p.append("%d komut yok %s" % [id, ins["c"]])
				if int(ins.get("n", 1)) != 1 or String(ins.get("k", "")) != "":
					p.append("%d sayaç/koşul" % id)
		if int(d["slots"].get("p2", 0)) != 0 or prog["p2"].size() != 0:
			p.append("%d F2 kullanılmamalı" % id)
		if d.get("enable_clone", false) != ("C" in sol.get("main", [])):
			p.append("%d klon bayrağı" % id)
		if int(d["slots"]["p1"]) == 0 and "1" in d["cmds"]:
			p.append("%d boş F1 çağrısı" % id)
		var gk := _geom_key(d)
		if seen.has(gk):
			p.append("%d geometri %d ile aynı" % [id, int(seen[gk])])
		seen[gk] = id
		if names.has(d["name"]):
			p.append("%d ad çakışması" % id)
		names[d["name"]] = true
	p.append_array(_phase_problems(levels))
	return p


func _strip_sims(levels: Array) -> void:
	for d in levels:
		d.erase("sims")


func _summary(levels: Array) -> void:
	var fn := 0
	var clone := 0
	var par_sum := 0
	var mn := 99
	var mx := 0
	print("Faz  Bileşen dağılımı")
	for ph in 10:
		var c := {"DIODE": 0, "CAPACITOR": 0, "RESISTOR": 0, "RELAY": 0, "OR": 0, "AND": 0, "BOOST2": 0}
		var f1 := 0
		var cl := 0
		for k in 10:
			var d: Dictionary = levels[ph * 10 + k]
			var n := _comp_counts(d)
			for key in c:
				c[key] += int(n[key])
			if int(d["slots"]["p1"]) > 0 and not d.get("enable_clone", false):
				f1 += 1
				fn += 1
			if d.get("enable_clone", false):
				cl += 1
				clone += 1
			var pc := int(d["par_commands"])
			par_sum += pc
			mn = mini(mn, pc)
			mx = maxi(mx, pc)
		print("  %d. %-16s diyot %d  kap %d (2kat %d)  direnç %d  röle %d (OR %d AND %d)  F1 %d  klon %d" % [ph + 1, PHASE_SHORT[ph], c["DIODE"], c["CAPACITOR"], c["BOOST2"], c["RESISTOR"], c["RELAY"], c["OR"], c["AND"], f1, cl])
	print("par: min %d  max %d  ortalama %.1f  |  F1 seviye %d  klon seviye %d" % [mn, mx, float(par_sum) / 100.0, fn, clone])


## Komut listesini tekrar desenlerine göre sıkıştırır (tools/gen-extra.mjs içindeki compress ile aynı davranış).
## F1 için en fazla 6, F2 için en fazla 5 uzunlukta desen aranır; tekrarlar sırasıyla '1' ve '2' sembolleriyle
## değiştirilir. Dönüş: {"main": Array, "p1": Array, "p2": Array} — use_p2=false iken p2 boş kalır.
## daily_generator.gd ve diğer çağıranlar bu imzayı bekler; kök tools/ kopyasındaki bayt sıkıştırıcıdan farklıdır.
static func compress(cmds: Array, use_p1 := true, use_p2 := true) -> Dictionary:
	var main: Array = cmds.duplicate()
	var p1: Array = []
	var p2: Array = []
	if use_p1:
		var b1 := _best_repeat(main, 6)
		if not b1.is_empty():
			p1 = b1["pat"]
			main = _replace_seq(main, p1, "1")
	if use_p2:
		var b2 := _best_repeat(main, 5)
		if not b2.is_empty():
			p2 = b2["pat"]
			main = _replace_seq(main, p2, "2")
	return {"main": main, "p1": p1, "p2": p2}


## En kazançlı tekrar desenini bulur: save = occ * (uzunluk-1) - uzunluk; eşitse daha uzun desen kazanır.
static func _best_repeat(seq: Array, max_len: int) -> Dictionary:
	var best := {}
	for plen in range(2, max_len + 1):
		for i in range(0, seq.size() - plen + 1):
			var pat: Array = seq.slice(i, i + plen)
			var occ := 0
			var j := 0
			while j + plen <= seq.size():
				var eq := true
				for t in plen:
					if seq[j + t] != pat[t]:
						eq = false
						break
				if eq:
					occ += 1
					j += plen
				else:
					j += 1
			var save := occ * (plen - 1) - plen
			if occ >= 2 and save > 0 and (best.is_empty() or save > int(best["save"]) or (save == int(best["save"]) and plen > (best["pat"] as Array).size())):
				best = {"pat": pat, "save": save}
	return best


static func _replace_seq(seq: Array, pat: Array, sym: String) -> Array:
	var out: Array = []
	var j := 0
	while j < seq.size():
		var eq := j + pat.size() <= seq.size()
		if eq:
			for t in pat.size():
				if seq[j + t] != pat[t]:
					eq = false
					break
		if eq:
			out.append(sym)
			j += pat.size()
		else:
			out.append(seq[j])
			j += 1
	return out


func _generate() -> void:
	var specs := _specs()
	if specs.size() != 100:
		push_error("spec sayısı %d" % specs.size())
		quit(1)
		return
	var only := 0
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--only="):
			only = int(String(arg).substr(7))
	var levels: Array = []
	var sims := 0
	for i in 100:
		if only > 0 and i + 1 != only:
			continue
		var d := _finish_level(i + 1, _build(specs[i]))
		if d.is_empty():
			quit(1)
			return
		sims += int(d.get("sims", 0))
		d.erase("sims")
		levels.append(d)
		if only > 0:
			print("#%d par=%d slots=%s sol=%s" % [only, int(d["par_commands"]), str(d["slots"]), str(d["hint_solution"])])
			quit(0)
			return
	var probs := _structural(levels)
	if not probs.is_empty():
		for msg in probs:
			push_error(msg)
		quit(1)
		return
	_summary(levels)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "phases": _phase_meta(), "levels": levels}, "", false))
	f.close()
	print("levels_100: %d/%d solvable → %s  (arama %d)" % [levels.size(), levels.size(), OUT, sims])
	quit(0)


func _phase_meta() -> Array:
	var out := []
	for i in 10:
		out.append({"id": i + 1, "name": PHASE_SHORT[i], "hardware": PHASE_NAMES[i], "levels": [i * 10 + 1, i * 10 + 10], "mechanics": PHASE_MECH[i]})
	return out


func _check_file() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(OUT))
	if data == null or not (data is Dictionary):
		push_error("levels_100 okunamadı")
		quit(1)
		return
	var levels: Array = data["levels"]
	var probs := _structural(levels)
	var ok := 0
	var sims := 0
	for d in levels:
		var L := PuzzleLogic.new()
		L.load_level((d as Dictionary).duplicate(true))
		var sol: Dictionary = d["hint_solution"]
		var ran := Program.run_ticks(L, sol, [])
		if String(ran["result"]) != "win":
			probs.append("ÇÖZÜMSÜZ #%d %s" % [int(d["id"]), d["name"]])
			continue
		var clone := bool(d.get("enable_clone", false))
		var prims := ["F", "L", "R"]
		if "J" in d["cmds"]:
			prims.append("J")
		var bfs := _bfs(L, prims)
		if not clone:
			var steps := int(ran.get("steps", -1))
			if int(bfs["dist"]) < 0 or steps != int(bfs["dist"]):
				probs.append("ÇÖZÜMSÜZ #%d par kısa yol değil" % int(d["id"]))
				continue
			if int(d["slots"]["p1"]) == 0 and int(d["par_commands"]) != steps:
				probs.append("ÇÖZÜMSÜZ #%d par != bfs" % int(d["id"]))
				continue
		elif int(bfs["dist"]) >= 0:
			probs.append("ÇÖZÜMSÜZ #%d klonsuz çözülüyor" % int(d["id"]))
			continue
		if clone or int(d["slots"]["p1"]) > 0:
			var cheap := _cheaper_clone(L, d["slots"], d["cmds"], int(d["par_commands"]), d["hint_solution"].get("p1", [])) if clone else _cheaper(L, d["slots"], d["cmds"], int(d["par_commands"]), false)
			sims += int(cheap.get("sims", 0))
			if cheap.get("overflow", false) or cheap.get("found", false):
				probs.append("ÇÖZÜMSÜZ #%d par tutarsız" % int(d["id"]))
				continue
		ok += 1
	if not probs.is_empty():
		for msg in probs:
			print(msg)
			push_error(msg)
	_summary(levels)
	print("levels_100: %d/%d solvable" % [ok, levels.size()])
	quit(0 if ok == 100 and levels.size() == 100 and probs.is_empty() else 1)


func _init() -> void:
	if "--check" in OS.get_cmdline_user_args():
		_check_file()
	else:
		_generate()
