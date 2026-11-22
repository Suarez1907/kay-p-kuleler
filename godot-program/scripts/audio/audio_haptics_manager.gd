## Prosedürel mekanik ses (ASMR) ve haptik motoru — autoload "AudioHaptics".
## Bütün sesler açılışta BİR KEZ AudioStreamWAV (16 bit PCM) olarak bellekte üretilir ve önbelleğe alınır; çalma
## sırasında sentez yapılmaz (CPU yükü yok). Her ses tepe değeri 0.85'e normalize edilir, başı/sonu yumuşatılır
## (patlama/cızırtı yok) ve 10 oynatıcılık havuzdan çalınır.
## Özel ses dosyası: res://assets/audio/<ad>.wav ya da .ogg varsa üretilen sesin yerine o kullanılır
## (adlar: step0..step5, cap, error, relay, thock, snap, power, fan, post, chord).
## Titreşim: Input.vibrate_handheld yalnızca mobilde çağrılır; masaüstünde sessizce atlanır.
extends Node

const RATE := 22050
const OVERRIDE_DIR := "res://assets/audio/"
## C majör pentatonik: C5 D5 E5 G5 A5 C6
const PENTA := [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]

var sound_on := true
var haptics_on := true
var _sounds := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _fan: AudioStreamPlayer
var _fan_level := 0.0
var _step_i := 0

func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_build_all()
	_fan = AudioStreamPlayer.new()
	_fan.stream = _sounds["fan"]
	_fan.volume_db = -80.0
	add_child(_fan)

func has_sound(n: String) -> bool:
	return _sounds.has(n)

func play(n: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not sound_on or not _sounds.has(n):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _sounds[n]
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()

# ---------- ASMR dosya motoru (varsa öncelikli; yoksa prosedürel sesler çalar) ----------
func _asmr() -> Node:
	var a := get_node_or_null("/root/ASMR")
	return a if a != null and a.available and sound_on else null

var _fan_prev := 0.0

# ---------- oynanış ----------
## Adım: pentatonik dizide yürür, yükseldikçe nota da yükselir
func step(height: int, pitch := 1.0) -> void:
	var a := _asmr()
	if a != null and a.play_step(height):
		return
	var idx := posmod(height + _step_i, PENTA.size())
	_step_i += 1
	play("step%d" % idx, pitch, -4.0)

func cap_launch() -> void:
	var a := _asmr()
	if a != null and a.play_component("capacitor"):
		return
	play("cap")

func error() -> void:
	var a := _asmr()
	if a == null or not a.play_component("diode"):
		play("error")
	vibrate_pattern([30, 30])

func relay() -> void:
	var a := _asmr()
	if a != null and a.play_component("relay"):
		return
	play("relay")

func ui_thock() -> void:
	var a := _asmr()
	if a == null or not a.play_ui_thock():
		play("thock", randf_range(0.95, 1.06))
	vibrate(12)

func snap() -> void:
	var a := _asmr()
	if a == null or not a.play_part_snap():
		play("snap")
	vibrate(45)

func power_press() -> void:
	var a := _asmr()
	if a == null or not a.play_power_switch():
		play("power")
	vibrate(60)

func post_beep() -> void:
	var a := _asmr()
	if a != null and a.play_bios_beep():
		return
	play("post")

func desktop_chord() -> void:
	var a := _asmr()
	if a != null and a.play_boot_chord():
		return
	play("chord")

## Fan sesi: 0 (sessiz) … 1 (tam devir). Devir arttıkça perde ve ses yükselir.
func fan(level: float) -> void:
	# ASMR: fan ilk kez dönmeye başlayınca 6 sn'lik kalkış sesi
	if level > 0.02 and _fan_prev <= 0.02:
		var a := _asmr()
		if a != null:
			a.play_fan_spinup()
	_fan_prev = level
	_fan_level = clampf(level, 0.0, 1.0)
	if _fan_level <= 0.001 or not sound_on:
		_fan.stop()
		return
	if not _fan.playing:
		_fan.play()
	_fan.pitch_scale = lerpf(0.55, 1.25, _fan_level)
	_fan.volume_db = linear_to_db(maxf(0.0001, _fan_level * 0.55))

# ---------- haptik ----------
func vibrate(ms: int) -> void:
	if not haptics_on or not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(ms)

func vibrate_pattern(list: Array, gap_ms := 70) -> void:
	if not haptics_on or not OS.has_feature("mobile"):
		return
	var t := 0.0
	for ms in list:
		if t <= 0.0:
			Input.vibrate_handheld(int(ms))
		else:
			get_tree().create_timer(t).timeout.connect(func(): Input.vibrate_handheld(int(ms)))
		t += (int(ms) + gap_ms) / 1000.0

# ---------------------------------------------------------------------------
# Sentez (bir kez, açılışta)
func _build_all() -> void:
	for i in PENTA.size():
		_put("step%d" % i, _marimba(PENTA[i]))
	_put("cap", _cap_sweep())
	_put("error", _error())
	_put("relay", _relay())
	_put("thock", _thock())
	_put("snap", _snap())
	_put("power", _power())
	_put("fan", _fan_loop())
	_put("post", _post())
	_put("chord", _chord())

func _put(n: String, b: PackedFloat32Array, loop := false) -> void:
	for ext in [".wav", ".ogg"]:
		var path: String = OVERRIDE_DIR + n + ext
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				_sounds[n] = res
				return
	_sounds[n] = _wav(b, n == "fan")

## Normalize (tepe 0.85) + 3 ms giriş/çıkış yumuşatması → 16 bit PCM
func _wav(b: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak := 0.0001
	for v in b:
		peak = maxf(peak, absf(v))
	var g := 0.85 / peak
	var fade := int(0.003 * RATE)
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		var v := b[i] * g
		if not loop:
			if i < fade:
				v *= float(i) / fade
			elif i > b.size() - fade:
				v *= float(b.size() - i) / fade
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = b.size()
	return w

static func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b

## sıcak elektronik marimba: temel + 4x kısmi (hızlı sönümlü) + yumuşak tokmak tıkı
func _marimba(f: float) -> PackedFloat32Array:
	var b := _buf(0.42)
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.004) * exp(-t * 9.0)
		var v := sin(TAU * f * t) * env
		v += 0.35 * sin(TAU * f * 3.93 * t) * minf(1.0, t / 0.002) * exp(-t * 32.0)
		v += 0.12 * sin(TAU * f * 0.5 * t) * env
		b[i] = v
	return b

func _cap_sweep() -> PackedFloat32Array:
	var b := _buf(0.32)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := lerpf(260.0, 1400.0, pow(t / 0.32, 1.6))
		ph += f / RATE
		var env := minf(1.0, t / 0.01) * (1.0 - t / 0.32)
		b[i] = (sin(TAU * ph) + 0.3 * sin(TAU * ph * 2.0)) * env
	return b

func _error() -> PackedFloat32Array:
	var b := _buf(0.24)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.004) * exp(-t * 14.0)
		lp += ((randf() * 2.0 - 1.0) - lp) * 0.05
		var body := sin(TAU * lerpf(110.0, 70.0, t / 0.24) * t)
		var buzz := 0.35 * signf(sin(TAU * 92.0 * t))
		b[i] = (body + buzz * 0.5 + lp * 1.2) * env
	return b

func _click(b: PackedFloat32Array, at: float, f: float, dur: float, vol: float) -> void:
	var s0 := int(at * RATE)
	for i in int(dur * RATE):
		if s0 + i >= b.size():
			break
		var t := float(i) / RATE
		var env := exp(-t * (6.0 / dur))
		b[s0 + i] += ((randf() * 2.0 - 1.0) * exp(-t * 900.0) + sin(TAU * f * t)) * env * vol

func _relay() -> PackedFloat32Array:
	var b := _buf(0.16)
	_click(b, 0.0, 2300.0, 0.03, 1.0)
	_click(b, 0.065, 3400.0, 0.025, 0.7)
	return b

## mekanik klavye "thock": kısık gürültü darbesi + tok 180 Hz gövde
func _thock() -> PackedFloat32Array:
	var b := _buf(0.07)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += ((randf() * 2.0 - 1.0) - lp) * 0.18
		b[i] = (lp * exp(-t * 160.0) * 1.6 + sin(TAU * 180.0 * t) * exp(-t * 55.0)) * minf(1.0, t / 0.0015)
	return b

## montaj oturması: keskin klik + metal tını + kısa lehim cızırtısı
func _snap() -> PackedFloat32Array:
	var b := _buf(0.32)
	_click(b, 0.0, 3600.0, 0.06, 1.0)
	_click(b, 0.012, 5200.0, 0.04, 0.45)
	for i in range(int(0.04 * RATE), b.size()):
		var t := float(i) / RATE - 0.04
		if randf() < 0.08:
			b[i] += (randf() * 2.0 - 1.0) * 0.32 * exp(-t * 14.0)
	return b

func _power() -> PackedFloat32Array:
	var b := _buf(0.3)
	_click(b, 0.0, 1800.0, 0.04, 1.0)
	for i in b.size():
		var t := float(i) / RATE
		b[i] += sin(TAU * 62.0 * t) * minf(1.0, t / 0.02) * exp(-t * 9.0) * 0.8
	return b

## fan: alçak geçiren gürültü + motor uğultusu; kesintisiz döngü (perde fan() ile ayarlanır)
func _fan_loop() -> PackedFloat32Array:
	var n := RATE * 2
	var b := PackedFloat32Array()
	b.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += ((randf() * 2.0 - 1.0) - lp) * 0.12
		lp2 += (lp - lp2) * 0.2
		b[i] = lp2 * 1.4 + 0.25 * sin(TAU * 120.0 * t) + 0.12 * sin(TAU * 240.0 * t)
	# döngü sınırında yumuşak geçiş
	var m := int(0.1 * RATE)
	for i in m:
		var k := float(i) / m
		b[i] = b[i] * k + b[n - m + i] * (1.0 - k)
	return b

## klasik anakart POST "BEEP"
func _post() -> PackedFloat32Array:
	var b := _buf(0.26)
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.006) * minf(1.0, (0.26 - t) / 0.02)
		b[i] = (sin(TAU * 1000.0 * t) * 0.7 + 0.3 * signf(sin(TAU * 1000.0 * t))) * env
	return b

## masaüstü açılış akoru: Cmaj7 (C4 E4 G4 B4 C5), sıcak, yavaş açılan synth
func _chord() -> PackedFloat32Array:
	var b := _buf(2.6)
	var notes := [261.63, 329.63, 392.0, 493.88, 523.25]
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.35) * exp(-t * 0.9)
		var v := 0.0
		for k in notes.size():
			var f: float = notes[k] * (1.0 + 0.0025 * sin(TAU * 0.4 * t + k))
			v += sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t) + 0.08 * sin(TAU * f * 3.0 * t)
		b[i] = v * env
	return b
