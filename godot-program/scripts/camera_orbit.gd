## Serbest kamera yörüngesi. Yatay açı 360°'nin herhangi bir yerinde durabilir;
## parmak/fare bırakılınca hız sönümlenir ve tam olarak sıfırlanır (boşta 30 FPS'e dönüşü kilitlemez).
## Yükseliş sabit izometrik açıdır: göz yanılması geçitleri bu yükselişte hizalanır.
## Mantıksal bakış (0..3) en yakın 90° diliminden okunur; bu sınıf yalnızca açı matematiğini tutar.
class_name CameraOrbit
extends RefCounted

const YAW0 := 45.0
const PITCH := 0.6154797
const ZOOM_MIN := 0.58
const ZOOM_MAX := 2.25
const DRAG_DEG_PER_PX := 0.38
const VEL_MAX := 640.0
const DAMP := 3.6
const VEL_STOP := 0.8
const ZOOM_DAMP := 5.5
const ZOOM_STOP := 0.02
const FOLLOW := 8.0
const SETTLE := 0.04

var yaw := 45.0
var yaw_visual := 45.0
var zoom := 1.0
var vel := 0.0
var zoom_vel := 0.0
var dragging := false

func canonical_view() -> int:
	return posmod(roundi((yaw - YAW0) / 90.0), 4)

static func yaw_for_view(view: int) -> float:
	return YAW0 + 90.0 * float(posmod(view, 4))

static func approach(current: float, target: float) -> float:
	return current + wrapf(target - current, -180.0, 180.0)

func adopt(y: float, visual: float, z: float) -> void:
	yaw = y
	yaw_visual = visual
	zoom = z
	vel = 0.0
	zoom_vel = 0.0
	dragging = false

func add_drag_px(dx: float, dt: float) -> void:
	var deg := dx * DRAG_DEG_PER_PX
	yaw += deg
	dragging = true
	if dt > 0.0001:
		var inst := clampf(deg / dt, -VEL_MAX, VEL_MAX)
		vel = clampf(lerpf(vel, inst, 0.5), -VEL_MAX, VEL_MAX)

func release() -> void:
	dragging = false

func zoom_by(factor: float, loose := false) -> void:
	if factor <= 0.0 or is_nan(factor) or is_inf(factor):
		return
	var lo := 0.4 if loose else ZOOM_MIN
	var hi := 4.0 if loose else ZOOM_MAX
	var before := zoom
	zoom = clampf(zoom * factor, lo, hi)
	if loose:
		zoom_vel = 0.0
		return
	if absf(zoom - before) < 0.0001:
		zoom_vel = 0.0
	else:
		zoom_vel = clampf(log(factor) * 8.0, -1.4, 1.4)

func tick(dt: float) -> void:
	dt = clampf(dt, 0.0, 0.05)
	if not dragging:
		if vel != 0.0:
			yaw += vel * dt
			vel *= exp(-DAMP * dt)
			if absf(vel) < VEL_STOP:
				vel = 0.0
		if zoom_vel != 0.0:
			zoom = clampf(zoom * exp(zoom_vel * dt), ZOOM_MIN, ZOOM_MAX)
			zoom_vel *= exp(-ZOOM_DAMP * dt)
			if absf(zoom_vel) < ZOOM_STOP or zoom <= ZOOM_MIN + 0.0001 or zoom >= ZOOM_MAX - 0.0001:
				zoom_vel = 0.0
				zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	var gap := yaw - yaw_visual
	if vel == 0.0 and not dragging and absf(gap) < SETTLE:
		yaw_visual = yaw
	else:
		yaw_visual += gap * minf(1.0, dt * FOLLOW)
	if absf(yaw) > 1080.0:
		var w := floorf(yaw / 360.0) * 360.0
		yaw -= w
		yaw_visual -= w

func busy() -> bool:
	return dragging or vel != 0.0 or zoom_vel != 0.0 or absf(yaw - yaw_visual) > SETTLE

func aim(view: int) -> void:
	vel = 0.0
	yaw = approach(yaw, yaw_for_view(view))
