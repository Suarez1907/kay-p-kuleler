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


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)
	_build_sounds()
	_music = AudioStreamPlayer.new()
	_music.volume_db = -17.0
	_music.stream = _build_music()
	add_child(_music)


func play(name: String, pitch := 1.0) -> void:
	if not sound_on or not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[name]
	p.pitch_scale = pitch
	p.play()

func set_music(on: bool) -> void:
	music_on = on
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
