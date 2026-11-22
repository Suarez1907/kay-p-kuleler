## AudioHaptics autoload'una güvenli erişim: autoload yoksa (ör. başsız test betikleri) çağrılar sessizce atlanır.
class_name Sfx
extends RefCounted

static func ah() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null("AudioHaptics")
	return null

static func call_ah(method: String, args := []) -> void:
	var a := ah()
	if a != null and a.has_method(method):
		a.callv(method, args)

## ASMR müzik/foley motoru (autoload "ASMR"). Autoload yoksa (ör. --script testleri) motor kendisi kurulur;
## dosyalar yoksa available = false olur ve çağrılar sessizce prosedürel seslere bırakılır.
static var _asmr_stub: Node = null
static func asmr() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		var n := (ml as SceneTree).root.get_node_or_null("ASMR")
		if n != null:
			return n
	if _asmr_stub == null or not is_instance_valid(_asmr_stub):
		_asmr_stub = load("res://scripts/audio/asmr_music_engine.gd").new()
		_asmr_stub.name = "ASMR"
		if ml is SceneTree:
			(ml as SceneTree).root.add_child.call_deferred(_asmr_stub)
	return _asmr_stub

