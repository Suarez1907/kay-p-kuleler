## Sinematik yönetmeni: Blender'da üretilen .glb animasyon paketlerini (assets/animations/) montaj sahnesinde oynatır.
##   seviye 100        → grand_finale_100.glb (FinalBootSequence kamerası ve veri kanalları)
##   seviye % 10 == 0  → phase_finale_0X.glb (12 sn, mekanik kilitler)
##   diğerleri          → level_end_rigs.glb içindeki faza uygun arketip (8 sn)
## Kazanılan parça PartSocketAnchor altına bağlanır; rig'in Camera3D'si etkin kamera olur. Zaman AssemblyScene'den gelir
## (seek): basılı tutma hızlandırması ve "Geç" aynen çalışır. Kare olayları (whoosh, oturma, kilit) çağırana bildirilir.
## Paket yüklenemezse begin() false döner ve AssemblyScene eski Tween akışına düşer.
class_name CinematicDirector
extends Node

signal cue(kind: String, world_pos: Vector3)

const DIR := "res://assets/animations/"
const FPS := 30.0
## faz (0..9) → montaj arketipi
const ARCH := ["anim_drop_snap", "anim_drop_snap", "anim_drop_snap", "anim_vertical_slide", "anim_angle_insert",
	"anim_vertical_slide", "anim_screw_lock", "anim_magnetic_orbit", "anim_vertical_slide", "anim_magnetic_orbit"]
## arketip → tam oturma karesi (Blender studio ile aynı)
const SNAP := {"anim_drop_snap": 135, "anim_angle_insert": 140, "anim_vertical_slide": 145, "anim_screw_lock": 160, "anim_magnetic_orbit": 225}
const WHOOSH_FRAME := 20
const PHASE_SNAP := 150

var rig: Node3D
var ap: AnimationPlayer
var cam: Camera3D
var anim := ""
var kind := ""
var duration := 8.0
var anchors := {}
var part_node: Node3D
var _part_parent: Node
var _part_xform := Transform3D.IDENTITY
var _events: Array = []
var _fired := {}
var _marker_hi := false
var robot: Node3D
var robot_ap: AnimationPlayer
var _robot_clip := ""

static func kind_for(part_id: int) -> String:
	if part_id >= 100:
		return "grand"
	if part_id % 10 == 0:
		return "phase"
	return "level"

static func archetype_for(part_id: int) -> String:
	return ARCH[clampi((part_id - 1) / 10, 0, 9)]

static func exists(file: String) -> bool:
	return ResourceLoader.exists(DIR + file)

## Paketi örnekler: {root, ap, cam, anchors{ad: Node3D}} ya da {}
static func load_rig(file: String) -> Dictionary:
	if not exists(file):
		return {}
	var ps = load(DIR + file)
	if not (ps is PackedScene):
		return {}
	var root: Node = (ps as PackedScene).instantiate()
	if not (root is Node3D):
		root.free()
		return {}
	var aps := root.find_children("*", "AnimationPlayer", true, false)
	var cams := root.find_children("*", "Camera3D", true, false)
	var out := {"root": root, "ap": aps[0] if aps.size() > 0 else null, "cam": cams[0] if cams.size() > 0 else null, "anchors": {}}
	for n in ["PartSocketAnchor", "RobotHelperAnchor", "SparkAnchor", "LockMarkers", "PowerButtonAnchor", "FanSpeed", "PowerLed",
			"KeyboardWave", "RobotFinaleAnchor"]:
		var nd := root.find_child(n, true, false)
		if nd != null:
			out["anchors"][n] = nd
	for k in 10:
		var w := root.find_child("PhaseWake_%02d" % (k + 1), true, false)
		if w != null:
			out["anchors"]["PhaseWake_%02d" % (k + 1)] = w
	if out["ap"] == null:
		root.free()
		return {}
	return out

## Montaj (seviye sonu / faz sonu) sinematiğini kurar. world: AssemblyScene'in 3D dünyası.
func begin(world: Node3D, part_id: int, node: Node3D, part_size: Vector3) -> bool:
	kind = kind_for(part_id)
	var file := "level_end_rigs.glb"
	anim = archetype_for(part_id)
	duration = 8.0
	if kind == "phase" and exists("phase_finale_%02d.glb" % (part_id / 10)):
		file = "phase_finale_%02d.glb" % (part_id / 10)
		anim = "phase_finale_%02d" % (part_id / 10)
		duration = 12.0
	else:
		kind = "level"
	var d := load_rig(file)
	if d.is_empty() or not (d["ap"] as AnimationPlayer).has_animation(anim) or d["cam"] == null:
		if not d.is_empty():
			(d["root"] as Node).free()
		return false
	rig = d["root"]
	ap = d["ap"]
	cam = d["cam"]
	anchors = d["anchors"]
	world.add_child(rig)
	if kind == "level":
		# birim parça için kurulmuş rig parça boyutuna ölçeklenir (kamera mesafesi dahil)
		var mx := maxf(part_size.x, maxf(part_size.y, part_size.z))
		var k := clampf(mx * 1.1, 0.45, 2.4)
		rig.scale = Vector3.ONE * k
		rig.position = node.position
	ap.assigned_animation = anim
	ap.play(anim)
	ap.pause()
	ap.seek(0.0, true)
	cam.current = true
	cam.near = 0.02
	# parçayı soket çapasına bağla (dünya ölçeği korunur)
	part_node = node
	_part_parent = node.get_parent()
	_part_xform = node.transform
	var sock: Node3D = anchors.get("PartSocketAnchor")
	if sock != null:
		_part_parent.remove_child(node)
		sock.add_child(node)
		node.transform = Transform3D.IDENTITY
		node.scale = Vector3.ONE / rig.scale
	_events = [{"f": WHOOSH_FRAME, "k": "whoosh"}, {"f": SNAP.get(anim, PHASE_SNAP) if kind == "level" else PHASE_SNAP, "k": "snap"}]
	_fired = {}
	_spawn_robot()
	return true

func _spawn_robot() -> void:
	var at: Node3D = anchors.get("RobotHelperAnchor")
	if at == null:
		return
	var path := DIR + "robot_cinematic_anims.glb"
	robot = AssetLoader.load_model(path, Vector3(0.5, 0.65, 0.5), true) if ResourceLoader.exists(path) else AssetLoader.robot_model()
	if robot == null:
		return
	robot.scale = Vector3.ONE / rig.scale
	at.add_child(robot)
	robot_ap = AssetLoader.anim_player(robot, [])
	_robot_clip = ""

func _robot_play(clip: String) -> void:
	if robot_ap == null or clip == _robot_clip:
		return
	for c in [clip, {"robot_inspect_snap": "look", "robot_level_victory": "victory"}.get(clip, "idle")]:
		if robot_ap.has_animation(c):
			robot_ap.play(c, 0.2)
			_robot_clip = clip
			return

## t (saniye) — AssemblyScene zamanı. Olaylar kare-bazlı tetiklenir.
func seek(t: float) -> void:
	if ap == null:
		return
	ap.seek(clampf(t, 0.0, ap.get_animation(anim).length), true)
	var fr := t * FPS
	for e in _events:
		if fr >= float(e["f"]) and not _fired.has(e["k"]):
			_fired[e["k"]] = true
			cue.emit(e["k"], _spark_pos())
	# faz sinematiklerinde ek kilit kareleri (LockMarkers.scale.x)
	var mk: Node3D = anchors.get("LockMarkers")
	if mk != null:
		var hi := mk.scale.x > 0.5
		if hi and not _marker_hi and absf(fr - PHASE_SNAP) > 2.0:
			cue.emit("lock", _spark_pos())
		_marker_hi = hi
	var snap_f: float = float(SNAP.get(anim, PHASE_SNAP)) if kind == "level" else float(PHASE_SNAP)
	_robot_play("robot_inspect_snap" if fr < snap_f + 10.0 else "robot_level_victory")

func _spark_pos() -> Vector3:
	var s: Node3D = anchors.get("SparkAnchor")
	return s.global_position if s != null else Vector3.ZERO

## Sinematik biter: parça kendi yerine geri döner, rig silinir
func end(restore_cam: Camera3D = null) -> void:
	if part_node != null and is_instance_valid(part_node) and _part_parent != null and is_instance_valid(_part_parent):
		var gp := part_node.get_parent()
		if gp != _part_parent:
			gp.remove_child(part_node)
			_part_parent.add_child(part_node)
		part_node.transform = _part_xform
	part_node = null
	if rig != null and is_instance_valid(rig):
		rig.queue_free()
	rig = null
	ap = null
	if restore_cam != null and is_instance_valid(restore_cam):
		restore_cam.current = true
