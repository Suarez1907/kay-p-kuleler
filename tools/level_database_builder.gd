extends SceneTree

## Level database builder tool.
## Usage:
##   godot --headless --script res://tools/level_database_builder.gd -- --check
##   godot --headless --script res://tools/level_database_builder.gd -- --build

const DEFAULT_OUTPUT_PATH: String = "res://data/level_database.lmbake"
const LEVELS_DIR: String = "res://levels"

var _check_only: bool = false
var _output_path: String = DEFAULT_OUTPUT_PATH


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in args:
		if arg == "--check":
			_check_only = true
		elif arg == "--build":
			_check_only = false
		elif arg.begins_with("--output="):
			_output_path = arg.substr("--output=".length())

	if _check_only:
		_run_check()
	else:
		_run_build()


func _run_check() -> void:
	print("[level_database_builder] check mode")
	var levels: Array[Dictionary] = _collect_levels()
	print("[level_database_builder] found %d level(s)" % levels.size())
	for level in levels:
		var id: String = String(level.get("id", ""))
		var seed_value: int = date_seed(id)
		print("  - %s (seed=%d)" % [id, seed_value])
	print("[level_database_builder] check OK")
	quit(0)


func _run_build() -> void:
	print("[level_database_builder] build mode")
	var levels: Array[Dictionary] = _collect_levels()
	var database: Dictionary = {
		"version": 1,
		"generated_at": Time.get_datetime_string_from_system(true),
		"levels": levels,
	}
	var json_text: String = JSON.stringify(database, "\t")
	var bytes: PackedByteArray = json_text.to_utf8_buffer()
	var compressed: PackedByteArray = bytes.compress(FileAccess.COMPRESSION_GZIP)
	var file: FileAccess = FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("[level_database_builder] cannot open output: %s" % _output_path)
		quit(1)
		return
	file.store_buffer(compressed)
	file.close()
	print("[level_database_builder] wrote %d level(s) to %s (%d bytes)" % [levels.size(), _output_path, compressed.size()])
	quit(0)


func _collect_levels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(LEVELS_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tscn"):
			var id: String = entry.get_basename()
			result.append({
				"id": id,
				"path": LEVELS_DIR.path_join(entry),
				"seed": date_seed(id),
			})
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	return result


## Deterministic seed derived from a level id / date string.
## Kept static so dependent scripts can call LevelDatabaseBuilder.date_seed(...).
static func date_seed(source: String) -> int:
	var hash_value: int = 2166136261
	for i in source.length():
		var c: int = source.unicode_at(i)
		hash_value = hash_value ^ c
		hash_value = (hash_value * 16777619) & 0xFFFFFFFF
	return hash_value


## Compress helper kept for callers that expect a static compress().
## Uses PackedByteArray.compress under the hood with an explicit signature.
static func compress(data: PackedByteArray, mode: int = FileAccess.COMPRESSION_GZIP) -> PackedByteArray:
	return data.compress(mode)
