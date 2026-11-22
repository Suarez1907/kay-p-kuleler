## Kayıp Kuleler — kodla üretilen sesler (dosya gerektirmez) ve yumuşak ortam müziği.
class_name GameAudio
extends Node

const RATE := 22050

var sound_on := true
var music_on := true
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _sounds := {}
var _music: AudioStreamPlayer
# hava durumu ortam sesleri (ilk ihtiyaçta üretilir)
const AMB_RATE := 11025
var _amb := {}              # "rain" / "wind" -> AudioStreamPlayer
var _amb_vol := {"rain": 0.0, "wind": 0.0}
var _thunders: Array = []
var _thunder_p: AudioStreamPlayer


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)
	_build_sounds()
	_music = AudioStreamPlayer.new()
	_music.volume_db = -17.0
	_title_music = _build_music()
	_music.stream = _title_music
	add_child(_music)


func play(name: String, pitch := 1.0) -> void:
	if not sound_on or not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[name]
	p.pitch_scale = pitch
	p.play()

## Yağmur ve rüzgâr döngülerinin hedef şiddeti (0..1); yumuşakça geçer.
func set_ambient(rain: float, wind: float) -> void:
	_amb_vol = {"rain": rain, "wind": wind}
	for k in _amb_vol:
		if _amb_vol[k] > 0.0 and not _amb.has(k):
			var p := AudioStreamPlayer.new()
			p.stream = _build_rain() if k == "rain" else _build_wind()
			p.volume_db = -60.0
			add_child(p)
			_amb[k] = p

func _process(dt: float) -> void:
	for k in _amb:
		var p: AudioStreamPlayer = _amb[k]
		var want: float = _amb_vol[k] if sound_on else 0.0
		var target_db := linear_to_db(maxf(want, 0.0001)) + (-10.0 if k == "rain" else -12.0)
		p.volume_db = lerpf(p.volume_db, target_db, minf(1.0, dt * 1.5))
		if want > 0.0 and not p.playing:
			p.play()
		elif want <= 0.0 and p.playing and p.volume_db < -50.0:
			p.stop()

## Gök gürültüsü: önce çatırtı, sonra uzun, dalgalanan uğultu
func thunder(vol := 1.0) -> void:
	if not sound_on:
		return
	if _thunders.is_empty():
		for v in 2:
			_thunders.append(_build_thunder(v))
		_thunder_p = AudioStreamPlayer.new()
		add_child(_thunder_p)
	_thunder_p.stream = _thunders[randi() % _thunders.size()]
	_thunder_p.volume_db = linear_to_db(clampf(vol, 0.05, 1.0)) - 3.0
	_thunder_p.pitch_scale = randf_range(0.85, 1.1)
	_thunder_p.play()

func _amb_wav(b: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var w := _wav(b, loop)
	w.mix_rate = AMB_RATE
	return w

## Kesintisiz döngü: sonun fazlası başla çapraz karıştırılır
func _seamless(b: PackedFloat32Array, n: int, m: int) -> PackedFloat32Array:
	for i in m:
		var k := float(i) / m
		b[i] = b[i] * k + b[n + i] * (1.0 - k)
	b.resize(n)
	return b

func _build_rain() -> AudioStreamWAV:
	var n := AMB_RATE * 4
	var m := AMB_RATE / 4
	var b := PackedFloat32Array()
	b.resize(n + m)
	var lp := 0.0
	var lp2 := 0.0
	for i in n + m:
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.55
		lp2 += (lp - lp2) * 0.08
		var v := (lp - lp2) * 0.9                       # bant geçiren hışırtı
		if randf() < 0.004:
			v += (randf() - 0.5) * 0.9                  # tek tük iri damla
		b[i] = v * 0.55
	return _amb_wav(_seamless(b, n, m), true)

func _build_wind() -> AudioStreamWAV:
	var n := AMB_RATE * 6
	var m := AMB_RATE / 2
	var b := PackedFloat32Array()
	b.resize(n + m)
	var br := 0.0
	var lp := 0.0
	for i in n + m:
		br = clampf(br + (randf() * 2.0 - 1.0) * 0.04, -1.0, 1.0) * 0.998   # kahverengi gürültü
		lp += (br - lp) * 0.05
		var t := float(i) / AMB_RATE
		var gust := 0.55 + 0.45 * sin(TAU * t / 6.0) * sin(TAU * t / 3.0 + 1.0)
		b[i] = lp * 1.6 * gust
	return _amb_wav(_seamless(b, n, m), true)

func _build_thunder(variant: int) -> AudioStreamWAV:
	var dur := 3.6 + variant * 0.8
	var n := int(AMB_RATE * dur)
	var b := PackedFloat32Array()
	b.resize(n)
	var br := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / AMB_RATE
		br = clampf(br + (randf() * 2.0 - 1.0) * 0.08, -1.0, 1.0) * 0.995
		lp += (br - lp) * 0.07
		var env := minf(1.0, t / 0.04) * exp(-t * (1.1 - variant * 0.2))
		var roll := 0.6 + 0.4 * sin(TAU * t * (1.3 + variant * 0.4)) * sin(TAU * t * 0.37)
		var crack := (randf() * 2.0 - 1.0) * exp(-t * 18.0) * 0.6
		b[i] = (lp * 2.4 * roll) * env + crack
	return _amb_wav(b, false)

# ---------- faz müziği ----------
## Her faza kendi akor dizisi, tempo ve arpej deseni: kök (Hz), akorlar (kökten yarım ton), BPM, arpej, pad tınısı.
const PHASE_MUSIC := [
	{"root": 261.63, "chords": [[0, 4, 7], [-3, 0, 4], [-7, -3, 0], [-5, -1, 2]], "bpm": 96, "arp": [0, 1, 2, 1], "wave": "sine"},
	{"root": 293.66, "chords": [[0, 3, 7], [-2, 2, 5], [-4, 0, 3], [-5, -2, 2]], "bpm": 100, "arp": [0, 2, 1, 2], "wave": "tri"},
	{"root": 246.94, "chords": [[0, 4, 7], [5, 9, 12], [-3, 0, 4], [7, 11, 14]], "bpm": 108, "arp": [0, 1, 2, 3], "wave": "tri"},
	{"root": 220.0, "chords": [[0, 3, 7], [-4, 0, 3], [-7, -4, 0], [-2, 2, 5]], "bpm": 104, "arp": [2, 1, 0, 1], "wave": "sine"},
	{"root": 329.63, "chords": [[0, 4, 7], [-5, -1, 2], [-3, 0, 4], [-7, -3, 0]], "bpm": 92, "arp": [0, 2, 1, 3], "wave": "sine"},
	{"root": 196.0, "chords": [[0, 4, 7], [2, 5, 9], [4, 7, 11], [5, 9, 12]], "bpm": 112, "arp": [0, 1, 2, 1], "wave": "tri"},
	{"root": 233.08, "chords": [[0, 3, 7], [3, 7, 10], [-2, 2, 5], [-4, 0, 3]], "bpm": 88, "arp": [0, 2, 0, 1], "wave": "sine"},
	{"root": 277.18, "chords": [[0, 4, 7], [-1, 2, 7], [-3, 0, 4], [-5, -1, 2]], "bpm": 116, "arp": [0, 1, 2, 3], "wave": "tri"},
	{"root": 207.65, "chords": [[0, 3, 7], [-2, 2, 5], [1, 5, 8], [-4, 0, 3]], "bpm": 100, "arp": [3, 2, 1, 0], "wave": "sine"},
	{"root": 261.63, "chords": [[0, 4, 7, 11], [-3, 0, 4, 7], [5, 9, 12, 16], [7, 11, 14, 17]], "bpm": 120, "arp": [0, 1, 2, 3], "wave": "tri"},
	{"root": 246.94, "chords": [[0, 4, 7], [2, 5, 9], [-3, 0, 4], [-1, 2, 7]], "bpm": 104, "arp": [0, 2, 1, 2], "wave": "sine"},
]
var _phase := -2
var _phase_cache := {}
var _phase_pending := {}
var _phase_def: Dictionary = {}

## -1: başlık müziği (eski döngü), 0..9: faz, 10: özel/günlük. Üretim arka plan iş parçacığında yapılır.
func set_phase(p: int) -> void:
	if p == _phase:
		return
	_phase = p
	# ASMR dosya müziği varsa oyun içi müzik onundur; başlıkta (p < 0) eski döngü çalar
	var asmr := get_node_or_null("/root/ASMR")
	if asmr != null and asmr.available:
		asmr.set_level_phase(p if p < 10 else 9)
		if p >= 0:
			_phase_def = {}
			var tw0 := create_tween()
			tw0.tween_property(_music, "volume_db", -60.0, 0.8)
			tw0.tween_callback(_music.stop)
			return
		_music.stream = _title_music
		_music.volume_db = -17.0
		if music_on and not _music.playing:
			_music.play()
		return
	if p < 0:
		_swap(_title_music)
		_phase_def = {}
		return
	_phase_def = PHASE_MUSIC[clampi(p, 0, PHASE_MUSIC.size() - 1)]
	if _phase_cache.has(p):
		_swap(_phase_cache[p])
		return
	if _phase_pending.has(p):
		return
	_phase_pending[p] = WorkerThreadPool.add_task(func():
		var w := _build_phase_music(p)
		call_deferred("_phase_ready", p, w))

## Kapanışta arka plandaki müzik üretimi bitmeden düğüm silinmesin
func _exit_tree() -> void:
	for p in _phase_pending:
		WorkerThreadPool.wait_for_task_completion(int(_phase_pending[p]))
	_phase_pending.clear()

func _phase_ready(p: int, w: AudioStreamWAV) -> void:
	if _phase_pending.has(p):
		WorkerThreadPool.wait_for_task_completion(int(_phase_pending[p]))
	_phase_pending.erase(p)
	_phase_cache[p] = w
	if _phase == p:
		_swap(w)

var _title_music: AudioStreamWAV

func _swap(w: AudioStreamWAV) -> void:
	if w == null or _music.stream == w:
		return
	var was := _music.playing
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, 0.4)
	tw.tween_callback(func():
		_music.stream = w
		if was or music_on:
			if music_on:
				_music.play()
	)
	tw.tween_property(_music, "volume_db", -17.0, 0.8)

## Robo'nun adım sesi o anki akorun köküne göre transpoze edilir (müzikle uyumlu)
func harmony_pitch() -> float:
	if _phase_def.is_empty() or not _music.playing or not music_on:
		return 1.0
	var beat := 60.0 / float(_phase_def["bpm"])
	var bar := int(_music.get_playback_position() / (beat * 4.0)) % 4
	var semi: int = _phase_def["chords"][bar][0]
	var r := pow(2.0, semi / 12.0) * float(_phase_def["root"]) / 261.63
	while r > 1.3:
		r *= 0.5
	while r < 0.77:
		r *= 2.0
	return r

func _build_phase_music(p: int) -> AudioStreamWAV:
	var d: Dictionary = PHASE_MUSIC[clampi(p, 0, PHASE_MUSIC.size() - 1)]
	var beat := 60.0 / float(d["bpm"])
	var bars := 8
	var b := PackedFloat32Array()
	b.resize(int(beat * 4.0 * bars * RATE))
	var root: float = d["root"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + p * 31
	for bar in bars:
		var ch: Array = d["chords"][bar % 4]
		var t0 := bar * beat * 4.0
		# pad: akor notaları uzun ve yumuşak
		for semi in ch:
			var f := root * pow(2.0, float(semi) / 12.0) * 0.5
			_tone(b, f, beat * 4.4, "sine", 0.045, 0.0, t0, 0.6)
		# bas: kök, 1. ve 3. vuruş
		var bf := root * pow(2.0, float(ch[0]) / 12.0) * 0.25
		_tone(b, bf, beat * 1.6, "sine", 0.07, 0.0, t0, 0.02)
		_tone(b, bf, beat * 1.6, "sine", 0.05, 0.0, t0 + beat * 2.0, 0.02)
		# arpej: sekizlik notalar, akor tonları üzerinde desen
		var arp: Array = d["arp"]
		for k in 8:
			var idx: int = arp[k % arp.size()] % ch.size()
			var f2 := root * pow(2.0, float(ch[idx]) / 12.0) * (2.0 if k % 4 == 3 else 1.0)
			_tone(b, f2, beat * 0.45, d["wave"], 0.03 + rng.randf() * 0.008, 0.0, t0 + k * beat * 0.5, 0.004)
		# hafif hi-hat (gürültü tıkı)
		for k in 4:
			_tone(b, 6000.0, 0.03, "noise", 0.012, 0.0, t0 + k * beat + beat * 0.5, 0.001)
	var fade := int(0.03 * RATE)
	for i in fade:
		b[i] *= float(i) / fade
		b[b.size() - 1 - i] *= float(i) / fade
	return _wav(b, true)

func set_music(on: bool) -> void:
	music_on = on
	var asmr := get_node_or_null("/root/ASMR")
	if asmr != null:
		asmr.set_music_enabled(on)
		if asmr.available and _phase >= 0:
			if not on:
				_music.stop()
			return
	if on and not _music.playing:
		_music.play()
	elif not on:
		_music.stop()


# ---------- sentez ----------
func _tone(buf: PackedFloat32Array, f: float, dur: float, shape := "sine", vol := 0.5, slide := 0.0, delay := 0.0, attack := 0.008) -> void:
	var start := int(delay * RATE)
	var n := int(dur * RATE)
	if buf.size() < start + n:
		buf.resize(start + n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var fr := f + slide * t
		ph += fr / RATE
		var v := 0.0
		match shape:
			"sine": v = sin(TAU * ph)
			"tri": v = 1.0 - 4.0 * absf(fposmod(ph, 1.0) - 0.5)
			"square": v = 1.0 if fposmod(ph, 1.0) < 0.5 else -1.0
			"noise": v = randf() * 2.0 - 1.0
		var env := minf(1.0, float(i) / maxf(1.0, attack * RATE)) * pow(1.0 - t, 2.2)
		buf[start + i] += v * vol * env

func _wav(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = buf.size()
	return w

func _snd(parts: Array) -> AudioStreamWAV:
	var b := PackedFloat32Array()
	for p in parts:
		_tone(b, p[0], p[1], p[2], p[3], p[4] if p.size() > 4 else 0.0, p[5] if p.size() > 5 else 0.0)
	return _wav(b)

func _build_sounds() -> void:
	_sounds["tap"] = _snd([[1250.0, 0.05, "sine", 0.35]])
	_sounds["pop"] = _snd([[660.0, 0.09, "sine", 0.4, 420.0]])
	_sounds["del"] = _snd([[520.0, 0.09, "tri", 0.3, -260.0]])
	_sounds["step"] = _snd([[540.0, 0.07, "tri", 0.28, -140.0]])
	_sounds["turn"] = _snd([[700.0, 0.06, "tri", 0.2, 140.0]])
	_sounds["jump"] = _snd([[330.0, 0.2, "tri", 0.32, 520.0]])
	_sounds["bump"] = _snd([[150.0, 0.13, "square", 0.12, -40.0], [90.0, 0.1, "sine", 0.35]])
	_sounds["click"] = _snd([[900.0, 0.05, "square", 0.12], [1350.0, 0.05, "square", 0.08, 0.0, 0.05]])
	_sounds["push"] = _snd([[140.0, 0.16, "sine", 0.45, -40.0], [400.0, 0.16, "noise", 0.18]])
	_sounds["mech"] = _snd([[220.0, 0.28, "tri", 0.18, 110.0], [800.0, 0.2, "noise", 0.08]])
	_sounds["bridge"] = _snd([[523.0, 0.3, "sine", 0.25], [659.0, 0.3, "sine", 0.25, 0.0, 0.06], [784.0, 0.35, "sine", 0.25, 0.0, 0.12]])
	_sounds["crumble"] = _snd([[300.0, 0.4, "noise", 0.35, -200.0]])
	_sounds["fail"] = _snd([[420.0, 0.55, "tri", 0.3, -300.0]])
	_sounds["run"] = _snd([[392.0, 0.12, "tri", 0.22], [587.0, 0.16, "tri", 0.22, 0.0, 0.07]])
	_sounds["pause"] = _snd([[587.0, 0.12, "tri", 0.22], [392.0, 0.16, "tri", 0.22, 0.0, 0.07]])
	_sounds["star"] = _snd([[1046.0, 0.25, "sine", 0.3], [1568.0, 0.3, "sine", 0.15, 0.0, 0.04]])
	_sounds["win"] = _snd([[523.0, 0.5, "tri", 0.25], [659.0, 0.5, "tri", 0.25, 0.0, 0.1], [784.0, 0.5, "tri", 0.25, 0.0, 0.2], [1046.0, 0.8, "tri", 0.25, 0.0, 0.3], [1568.0, 0.9, "sine", 0.12, 0.0, 0.45]])
	_sounds["whoosh"] = _snd([[900.0, 0.22, "noise", 0.12, -600.0]])

## 16 sn'lik döngü: yavaş akorlar + seyrek çan notaları (pentatonik)
func _build_music() -> AudioStreamWAV:
	var b := PackedFloat32Array()
	var total := 16.0
	b.resize(int(total * RATE))
	var chords := [[261.6, 329.6, 392.0], [220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [196.0, 246.9, 293.7]]
	for ci in chords.size():
		for f in chords[ci]:
			_tone(b, f, 4.6, "sine", 0.05, 0.0, ci * 4.0, 1.2)
			_tone(b, f * 2.0, 4.2, "sine", 0.015, 0.0, ci * 4.0 + 0.1, 1.5)
	var bells := [784.0, 659.3, 523.3, 587.3, 659.3, 784.0, 880.0, 659.3]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for k in bells.size():
		_tone(b, bells[k], 1.6, "sine", 0.045, 0.0, k * 2.0 + rng.randf() * 0.4, 0.01)
	# döngü sınırında tıklamayı önlemek için uçları yumuşat
	var fade := int(0.05 * RATE)
	for i in fade:
		b[i] *= float(i) / fade
		b[b.size() - 1 - i] *= float(i) / fade
	return _wav(b, true)
