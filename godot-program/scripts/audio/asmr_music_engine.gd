## ASMR müzik ve dokunsal foley motoru — autoload "ASMR".
## Sesler tools/generate_asmr_audio.py ile üretilen dosyalardır (assets/audio/{music,sfx,assembly}).
##
## Müzik: aktif donanım faz grubunun (1–2, 3–4, 5–6, 7–8, 9–10) think / code / run katmanları tek bir
## AudioStreamSynchronized içinde birlikte çalar; katman sesleri oyun durumuna göre Tween ile karışır:
##   düşünme: think 0 dB, code −60, run −60 · kodlama: code −6 dB (4 sn işlem yoksa geri iner)
##   çalıştırma: run −2 dB (robot durunca geri çekilir) · faz grubu değişimi: iki oynatıcı arasında 1.5 sn çapraz geçiş
## Menü / duraklatma: ASMR_Music yolundaki alçak geçiren filtre 750 Hz'e iner (boğuk odak hissi).
## Foley: çok varyasyonlu sesler AudioStreamRandomizer ile sarılır (random_pitch 1.04, ±1.2 dB).
## Ses yolları: ASMR_Music, Foley_UI, Circuit_SFX (default_bus_layout.tres). Dosyalar eksikse available = false
## olur ve oyun eski prosedürel seslere (AudioHaptics / GameAudio) döner.
extends Node

const DIR := "res://assets/audio/"
const GROUPS := ["phase_1_2", "phase_3_4", "phase_5_6", "phase_7_8", "phase_9_10"]
const LAYERS := ["think", "code", "run"]
const SILENT := -60.0
const STEP_NOTES := ["c5", "d5", "e5", "g5", "a5", "c6"]
const CODE_HOLD := 4.0

var available := false
var music_on := true
var sfx_on := true
var group := -1
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _sync: Array = [null, null]          # oyuncu başına AudioStreamSynchronized
var _layer_db := [0.0, SILENT, SILENT]   # hedef katman sesleri
var _cur_db := [0.0, SILENT, SILENT]
var _layer_tw: Array = [null, null, null]
var _running := false
var _code_until := 0.0
var _clock := 0.0
var _focus := false
var _lp: AudioEffectLowPassFilter
var _lp_tw: Tween
var _streams := {}                       # ad -> AudioStream (randomizer dahil)
var _pool := {}                          # bus -> [AudioStreamPlayer]
var _pool_i := {}
var _step_i := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	available = _check_files()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "ASMR_Music" if AudioServer.get_bus_index("ASMR_Music") >= 0 else "Master"
		p.volume_db = SILENT
		add_child(p)
		_players.append(p)
	for bus in ["Foley_UI", "Circuit_SFX"]:
		var arr: Array[AudioStreamPlayer] = []
		for k in 8:
			var q := AudioStreamPlayer.new()
			q.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
			add_child(q)
			arr.append(q)
		_pool[bus] = arr
		_pool_i[bus] = 0
	var mb := AudioServer.get_bus_index("ASMR_Music")
	if mb >= 0:
		for e in AudioServer.get_bus_effect_count(mb):
			var fx := AudioServer.get_bus_effect(mb, e)
			if fx is AudioEffectLowPassFilter:
				_lp = fx
	if available:
		_load_sfx()

func _check_files() -> bool:
	for g in GROUPS:
		for l in LAYERS:
			if _find("music/%s_%s" % [g, l]) == "":
				return false
	return _find("sfx/ui_key_thock_01") != "" and _find("assembly/sfx_boot_chord") != ""

func _find(rel: String) -> String:
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(DIR + rel + ext):
			return DIR + rel + ext
	return ""

func _load(rel: String, loop := false) -> AudioStream:
	var p := _find(rel)
	if p == "":
		return null
	var s = load(p)
	if loop:
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		elif s is AudioStreamWAV:
			var w: AudioStreamWAV = s
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_end = int(w.get_length() * w.mix_rate)
	return s

func _randomizer(prefix: String, n: int) -> AudioStream:
	var r := AudioStreamRandomizer.new()
	r.random_pitch = 1.04
	r.random_volume_offset_db = 1.2
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	var k := 0
	for i in range(1, n + 1):
		var s := _load("%s_%02d" % [prefix, i])
		if s != null:
			r.add_stream(k, s)
			k += 1
	return r if k > 0 else null

func _load_sfx() -> void:
	_streams["thock"] = _randomizer("sfx/ui_key_thock", 4)
	_streams["smd"] = _randomizer("sfx/sfx_smd_pulse", 3)
	_streams["relay"] = _randomizer("sfx/sfx_relay_clack", 2)
	_streams["snap"] = _randomizer("assembly/sfx_part_snap", 3)
	for n in STEP_NOTES:
		_streams["step_" + n] = _load("sfx/step_note_" + n)
	for pair in [["diode", "sfx/sfx_diode_block"], ["cap", "sfx/sfx_capacitor_launch"], ["resistor", "sfx/sfx_resistor_tick"],
			["whoosh", "assembly/sfx_part_whoosh"], ["power", "assembly/sfx_power_switch"], ["fan_spinup", "assembly/sfx_fan_spinup"],
			["bios", "assembly/sfx_bios_beep"], ["boot", "assembly/sfx_boot_chord"]]:
		_streams[pair[0]] = _load(pair[1])

func has_stream(n: String) -> bool:
	return _streams.has(n) and _streams[n] != null

# ---------------------------------------------------------------------------
# müzik
## Seviye fazından (0..9) grup seçer; -1 = müziği durdur (başlık kendi müziğini kullanır)
func set_level_phase(phase_idx: int) -> void:
	if not available:
		return
	if phase_idx < 0:
		_fade_out_all()
		group = -1
		return
	set_group(clampi(phase_idx / 2, 0, GROUPS.size() - 1))

func set_group(g: int) -> void:
	if not is_inside_tree():
		return
	if not available or g == group:
		return
	group = g
	var nxt := 1 - _active
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = 3
	for i in 3:
		sync.set_sync_stream(i, _load("music/%s_%s" % [GROUPS[g], LAYERS[i]], true))
		sync.set_sync_stream_volume(i, _cur_db[i])
	_sync[nxt] = sync
	var pn := _players[nxt]
	var po := _players[_active]
	pn.stream = sync
	pn.volume_db = SILENT
	if music_on:
		pn.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(pn, "volume_db", 0.0, 1.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(po, "volume_db", SILENT, 1.5).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func(): if _players.find(po) != _active: po.stop())
	_active = nxt

func _fade_out_all() -> void:
	if not is_inside_tree():
		return
	for p in _players:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", SILENT, 1.0)
			tw.tween_callback(p.stop)

func set_music_enabled(on: bool) -> void:
	music_on = on
	if not available:
		return
	var p := _players[_active]
	if on and group >= 0 and not p.playing and p.stream != null:
		p.volume_db = 0.0
		p.play()
	elif not on:
		for q in _players:
			q.stop()

func set_sfx_enabled(on: bool) -> void:
	sfx_on = on

func _set_layer(i: int, db: float, dur: float) -> void:
	if not is_inside_tree():
		return
	if absf(_layer_db[i] - db) < 0.01:
		return
	_layer_db[i] = db
	if _layer_tw[i] != null:
		(_layer_tw[i] as Tween).kill()
	var tw := create_tween()
	tw.tween_method(func(v: float):
		_cur_db[i] = v
		for s in _sync:
			if s != null:
				(s as AudioStreamSynchronized).set_sync_stream_volume(i, v), _cur_db[i], db, dur).set_trans(Tween.TRANS_SINE)
	_layer_tw[i] = tw

## Kod düzenlendi (komut eklendi/silindi/seçildi): code katmanı yükselir, 4 sn sessizlikte iner
func notify_code() -> void:
	_code_until = _clock + CODE_HOLD
	_set_layer(1, -6.0, 0.6)

## Çalıştır açık/kapalı: run katmanı
func set_running(on: bool) -> void:
	_running = on
	_set_layer(2, -2.0 if on else SILENT, 0.8 if on else 1.2)

## Menü / duraklatma odağı: müzik boğuklaşır (750 Hz)
func set_focus(on: bool) -> void:
	if not is_inside_tree():
		return
	if on == _focus or _lp == null:
		return
	_focus = on
	if _lp_tw:
		_lp_tw.kill()
	_lp_tw = create_tween()
	_lp_tw.tween_method(func(v: float): _lp.cutoff_hz = v, _lp.cutoff_hz, 750.0 if on else 20000.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func layer_state() -> Array:
	return _cur_db.duplicate()

func _process(dt: float) -> void:
	_clock += dt
	if _layer_db[1] > SILENT and _clock > _code_until:
		_set_layer(1, SILENT, 1.2)

# ---------------------------------------------------------------------------
# foley
func play(n: String, bus := "Foley_UI", vol_db := 0.0, pitch := 1.0) -> bool:
	if not sfx_on or not has_stream(n) or not is_inside_tree() or not _pool.has(bus):
		return false
	var arr: Array = _pool[bus]
	var i: int = _pool_i[bus]
	_pool_i[bus] = (i + 1) % arr.size()
	var p: AudioStreamPlayer = arr[i]
	p.stream = _streams[n]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()
	return true

func play_ui_thock() -> bool:
	return play("thock", "Foley_UI", -3.0)

## Adım: kat yüksekliği + adım sayacına göre pentatonik nota (C5 D5 E5 G5 A5 C6)
func play_step(grid_y: int) -> bool:
	var idx := posmod(grid_y + _step_i, STEP_NOTES.size())
	_step_i += 1
	return play("step_" + STEP_NOTES[idx], "Circuit_SFX", -7.0)

func play_component(kind: String) -> bool:
	match kind:
		"smd": return play("smd", "Circuit_SFX", -10.0)
		"diode": return play("diode", "Circuit_SFX", -2.0)
		"capacitor": return play("cap", "Circuit_SFX", -2.0)
		"resistor": return play("resistor", "Circuit_SFX", -4.0)
		"relay": return play("relay", "Circuit_SFX", -2.0)
	return false

func play_part_whoosh() -> bool:
	return play("whoosh", "Foley_UI", -4.0)

func play_part_snap() -> bool:
	return play("snap", "Foley_UI", 0.0)

func play_power_switch() -> bool:
	return play("power", "Foley_UI", 0.0)

func play_fan_spinup() -> bool:
	return play("fan_spinup", "Circuit_SFX", -3.0)

func play_bios_beep() -> bool:
	return play("bios", "Foley_UI", -6.0)

func play_boot_chord() -> bool:
	return play("boot", "Foley_UI", -2.0)
