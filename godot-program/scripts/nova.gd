## Nova — oyunun yapay zekâ öğretmeni.
## Başarısız bir çalıştırmayı (düşme, takılma, sonsuz döngü, yarım kalan program) kurallarla analiz eder,
## sorunlu bloğu bulur ve öğretici bir açıklama üretir. Kazanılan programlarda tekrar eden desenleri
## yakalayıp fonksiyon önerir. Tamamen cihaz üzerinde çalışır, ağ gerektirmez.
class_name Nova
extends RefCounted

const ROW_NAME := {"main": "Ana programın", "p1": "F1'in", "p2": "F2'nin"}
const COND_NAME := {"o": "yeşil", "x": "turuncu"}

static func _cmd(c: String) -> String:
	return Program.COMMANDS[c]["name"] if Program.COMMANDS.has(c) else c

static func _where(ev: Dictionary) -> String:
	return "%s %d. bloğunda (%s)" % [ROW_NAME[ev["proc"]], int(ev["idx"]) + 1, _cmd(ev["c"])]

static func _calls_self(prog: Dictionary, row: String) -> Dictionary:
	var key := "1" if row == "p1" else "2"
	for ins in prog[row]:
		if ins["c"] == key:
			return ins
	return {}

## Robo'nun tam önünde etkileşilebilir bir şey var mı? ("kutu", "kol", "çark", "top" ya da "")
static func front_object(L: PuzzleLogic, s: Dictionary) -> String:
	if s["dead"]:
		return ""
	var W := L.build_world(s)
	var Q: Vector3i = s["p"] + PuzzleLogic.DIRS[s["f"]]
	var e = W["ents"].get(Q)
	if e != null:
		return "kutu" if e["k"] == "c" else ("top" if e["k"] == "b" else "")
	var sv = W["solid"].get(Q)
	if sv != null:
		return {"lv": "kol", "ck": "çark"}.get(sv["t"], "")
	return ""

## Robo bir nesneye takıldı ama hiç Kullan demediyse kısa bir gözlem
static func _use_note(L: PuzzleLogic, run: Dictionary) -> String:
	var fk := String(run.get("faced", ""))
	if fk == "" or run.get("used_A", false) or not ("A" in L.def.get("cmds", [])):
		return ""
	var verb: String = {"kutu": "itebilirdi", "kol": "çevirebilirdi", "çark": "döndürebilirdi", "top": "yuvarlayabilirdi"}[fk]
	var gen: String = {"kutu": "kutunun", "kol": "kolun", "çark": "çarkın", "top": "topun"}[fk]
	return " Gözlemim: Robo bir %s önünde durdu ama hiç Kullan demedi — Kullan ile onu %s." % [gen, verb]

## run: {last, first_bump, bumps, faced, used_A}
## Dönüş: {title, text, focus: {row, idx} | null}
static func analyze(L: PuzzleLogic, prog: Dictionary, s: Dictionary, reason: String, run: Dictionary) -> Dictionary:
	var last = run.get("last")
	var fb = run.get("first_bump")
	var bumps := int(run.get("bumps", 0))
	var out := {"title": "Nova'nın analizi", "text": "", "focus": null}
	match reason:
		"dead":
			if last != null and last["c"] == "W":
				out["text"] = "Mola sırasında Robo'nun altındaki zemin kayboldu ve Robo düştü. Bakış açısını ya da platformu değiştirmeden önce Robo'yu sağlam bir zemine götür."
			elif last != null:
				out["text"] = "Robo, %s sonra altındaki zemini kaybetti ve düştü. Bu adımdan önce zeminin sağlam kalacağından emin ol: çöken taşlar, kayan platformlar ve hayalet bloklar yer değiştirebilir." % _where(last)
				out["focus"] = {"row": last["proc"], "idx": last["idx"]}
			else:
				out["text"] = "Robo düştü. Programı adım adım (⏭) çalıştırıp hangi anda zeminin kaybolduğunu izle."
		"limit":
			var t := "Robo %d komutu aştı ama kristale ulaşamadı: program bir döngüde dönüp duruyor." % Program.MAX_STEPS
			for row in ["p1", "p2"]:
				var rec := _calls_self(prog, row)
				if not rec.is_empty() and rec["k"] == "" and not L.def.get("conds", false):
					t += " %s kendini koşulsuz çağırıyor; desenin kristale gerçekten götürdüğünü kontrol et." % ("F1" if row == "p1" else "F2")
					break
			if fb != null:
				t += " Robo ilk kez %s takıldı; döngü orada tıkanıyor olabilir." % _where(fb)
				out["focus"] = {"row": fb["proc"], "idx": fb["idx"]}
			elif L.def.get("conds", false):
				t += " Sonsuz bir döngüden çıkmak için koşullu bloklar kullan: örneğin önü kapalıyken dönmeyi ya da durmayı dene."
			out["text"] = t + _use_note(L, run)
		"loop":
			out["text"] = "Fonksiyon hiçbir şey yapmadan kendini çağırıyor: bütün bloklar koşul yüzünden atlanıyor. Kendini çağıran bloğu da koşullu yap (ör. yeşil F1) ki Robo duvara gelince döngü bitsin."
		"depth":
			out["text"] = "Çok fazla iç içe çağrı oldu: fonksiyonlar birbirini bitirmeden çağırıyor. Kendini çağıran bloğu fonksiyonun en sonuna koy; böylece döngü yığını büyütmeden döner."
		_:
			var path = L.find_path(s, L.goal)
			if fb != null:
				var row: Array = prog[fb["proc"]]
				var bi := int(fb["idx"])
				var prev = row[bi - 1] if bi > 0 and bi - 1 < row.size() else null
				if prev != null and prev["c"] in ["L", "R"]:
					out["text"] = "Robo %s ilk kez takıldı. Hemen önceki “%s” bloğuna bak: Robo yanlış yöne dönmüş olabilir." % [_where(fb), _cmd(prev["c"])]
					out["focus"] = {"row": fb["proc"], "idx": bi - 1}
				else:
					out["text"] = "Robo %s ilk kez bir engele takıldı. Bu bloktan önce Robo'nun doğru yöne baktığından emin ol; gerekirse adım adım (⏭) çalıştır." % _where(fb)
					out["focus"] = {"row": fb["proc"], "idx": bi}
				if bumps > 1:
					out["text"] += " Toplam %d takılma oldu." % bumps
				if path != null:
					out["text"] += " Program bittiğinde kristale %d adım vardı." % path.size()
			elif path != null:
				var n: int = path.size()
				if n <= 3:
					out["text"] = "Çok yaklaştın! Program bittiğinde Robo kristale yalnızca %d adım uzaktaydı. Programın sonuna birkaç blok ekle." % n
				else:
					out["text"] = "Program bitti ama Robo kristale daha %d adım uzakta. Tekrar eden bir desen varsa onu bir fonksiyona koyup döngüye çevirebilirsin." % n
			else:
				out["text"] = "Program bitti ama Robo'nun bulunduğu yerden kristale yürüyerek gidilemiyor. Önce bir mekanizmayı (kol, çark, kutu) kullanman ya da dünyayı değiştirmen gerekiyor olabilir."
			out["text"] += _use_note(L, run)
	return out

## Kazanılan ama par'ın üstündeki programlar için: ana programda tekrar eden desen var mı?
static func suggest(def: Dictionary, prog: Dictionary) -> String:
	var slots: Dictionary = def.get("slots", {})
	var free_row := ""
	for row in ["p1", "p2"]:
		if int(slots.get(row, 0)) > 0 and prog[row].is_empty() and (("1" if row == "p1" else "2") in def.get("cmds", [])):
			free_row = row
			break
	if free_row == "":
		return ""
	var m: Array = prog["main"]
	var best := {"save": 0}
	for k in range(1, mini(5, int(slots[free_row])) + 1):
		for start in m.size():
			var reps := 1
			while start + (reps + 1) * k <= m.size():
				var same := true
				for j in k:
					if Program.ins_to_str(m[start + j]) != Program.ins_to_str(m[start + reps * k + j]):
						same = false
						break
				if not same:
					break
				reps += 1
			var save := reps * k - (reps + k)
			if reps >= 2 and save > int(best["save"]):
				var names := []
				for j in k:
					names.append(_cmd(m[start + j]["c"]))
				best = {"save": save, "reps": reps, "names": names}
	if int(best["save"]) <= 0:
		return ""
	return "Nova: ana programda “%s” deseni %d kez tekrar ediyor. Onu %s'e taşırsan %d blok kazanırsın." % [", ".join(best["names"]), best["reps"], "F1" if free_row == "p1" else "F2", best["save"]]
