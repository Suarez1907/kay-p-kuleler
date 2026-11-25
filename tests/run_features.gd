extends SceneTree

const MAX_STEPS := 10000
const MAX_FRAMES := 600

var _steps := 0
var _frames := 0

func _init() -> void:
	_run()

func _run() -> void:
	if not _test_features():
		return
	print("TAMAM")
	quit(0)

func _test_features() -> bool:
	for i in range(10):
		if not _step():
			return false
	return true

func _step() -> bool:
	_steps += 1
	if _steps > MAX_STEPS:
		_fail("Adim limiti asildi")
		return false
	return true

func _wait_frame() -> bool:
	_frames += 1
	if _frames > MAX_FRAMES:
		_fail("Frame limiti asildi")
		return false
	return true

func _fail(msg: String) -> void:
	printerr("HATA: " + msg)
	quit(1)
