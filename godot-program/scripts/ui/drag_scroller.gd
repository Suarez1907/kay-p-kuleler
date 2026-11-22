## Sürükle-kaydır: bir ScrollContainer'ı, içindeki butonlar dokunuşu yutsa bile parmakla/fareyle kaydırır.
## Olaylar _input'ta (GUI'den önce) okunur: basılan nokta hedefin içindeyse ve parmak eşikten fazla kayarsa
## kaydırma başlar; bırakınca olay tüketilir (altındaki buton açılmaz). Kısa dokunuş butona normal geçer.
## ScrollContainer'ın kendi sürüklemesi kapatılır (MOUSE_FILTER_IGNORE) ki dokunmatikte çift kaydırma olmasın;
## fare tekerleği de burada işlenir. Bırakınca hızla süzülme (atalet) uygulanır.
class_name DragScroller
extends Node

const THRESHOLD := 12.0

var target: ScrollContainer
var horizontal := false
var _down := false
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _dragging := false
var _vel := 0.0
var _last_t := 0

static func attach(sc: ScrollContainer, is_horizontal := false) -> DragScroller:
	var d := DragScroller.new()
	d.target = sc
	d.horizontal = is_horizontal
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(d)
	return d

func _axis(v: Vector2) -> float:
	return v.x if horizontal else v.y

func _scroll_by(delta: float) -> void:
	if horizontal:
		target.scroll_horizontal = int(target.scroll_horizontal - delta)
	else:
		target.scroll_vertical = int(target.scroll_vertical - delta)

func _inside(p: Vector2) -> bool:
	return target.is_visible_in_tree() and target.get_global_rect().has_point(p)

func _input(e: InputEvent) -> void:
	if target == null or not target.is_visible_in_tree():
		_down = false
		return
	if e is InputEventMouseButton:
		var mb: InputEventMouseButton = e
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT] and mb.pressed and _inside(mb.position):
			var s := 60.0 * (1.0 if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else -1.0)
			_scroll_by(s)
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if _inside(mb.position):
				_down = true
				_dragging = false
				_start = mb.position
				_last = mb.position
				_vel = 0.0
				_last_t = Time.get_ticks_msec()
		else:
			if _down and _dragging:
				# sürükleme bitti: bırakma olayı butona gitmesin
				get_viewport().set_input_as_handled()
			_down = false
			_dragging = false
	elif e is InputEventMouseMotion and _down:
		var mm: InputEventMouseMotion = e
		if not _dragging and absf(_axis(mm.position - _start)) > THRESHOLD:
			_dragging = true
			_last = mm.position
		if _dragging:
			var d := _axis(mm.position - _last)
			_scroll_by(d)
			var now := Time.get_ticks_msec()
			var dt := maxf(1.0, float(now - _last_t)) / 1000.0
			_vel = lerpf(_vel, d / dt, 0.5)
			_last_t = now
			_last = mm.position
			get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if _down or absf(_vel) < 20.0:
		if not _down:
			_vel = 0.0
		return
	_scroll_by(_vel * dt)
	_vel *= pow(0.04, dt)
