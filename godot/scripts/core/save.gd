extends Node
## Settings + records persisted to user://settings.json (works on web via IndexedDB).

const PATH := "user://settings.json"

var lang: String = "ko"
var sound: bool = true
var timer_enabled: bool = true
var best_floor: int = 0
var runs_played: int = 0
var victories: int = 0


func _ready() -> void:
	lang = "ko" if OS.get_locale_language() == "ko" else "en"
	load_settings()


func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if parsed.get("lang") in ["ko", "en"]:
		lang = parsed["lang"]
	sound = bool(parsed.get("sound", true))
	timer_enabled = bool(parsed.get("timer", true))
	best_floor = clampi(int(parsed.get("bestFloor", 0)), 0, 7)
	runs_played = maxi(0, int(parsed.get("runsPlayed", 0)))
	victories = maxi(0, int(parsed.get("victories", 0)))


func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("settings not saved: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify({
		"lang": lang, "sound": sound, "timer": timer_enabled,
		"bestFloor": best_floor, "runsPlayed": runs_played, "victories": victories,
	}))
	f.close()


func record_run_end(level_reached: int, won: bool) -> void:
	runs_played += 1
	if won:
		victories += 1
		best_floor = 7
	else:
		best_floor = maxi(best_floor, level_reached)
	save_settings()
