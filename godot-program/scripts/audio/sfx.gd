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
