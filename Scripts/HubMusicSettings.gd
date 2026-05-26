extends Node

# ── Persistant Hub Music Selector (Autoload) ─────────────────────────────
# Stocke la sélection de musique du Hub et la sauvegarde dans user://hub_music.cfg
# Fournit la liste des morceaux disponibles aux autres scripts (PauseMenu, Hub)

signal music_changed(track_name: String)

var _track_names: Array[String] = []
var _track_files: Array[String] = []
var _selected_index: int = 0
var _loaded: bool = false

const CONFIG_PATH := "user://hub_music.cfg"
const CONFIG_SECTION := "hub_music"


func _ready() -> void:
	_scan_tracks()
	_load_selection()
	_loaded = true


func _scan_tracks() -> void:
	_track_names.clear()
	_track_files.clear()
	var dir := DirAccess.open("res://audio/hub/")
	if not dir:
		print("HubMusicSettings: Impossible d'accéder à res://audio/hub/")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var seen: Dictionary = {}
	while file_name != "":
		if not dir.current_is_dir():
			var original := file_name
			# Certains builds Godot listent les .mp3.import au lieu des .mp3
			if file_name.ends_with(".import"):
				original = file_name.replace(".import", "")
			if original.ends_with(".mp3") or original.ends_with(".ogg") or original.ends_with(".wav"):
				if not seen.has(original):
					seen[original] = true
					_track_files.append(original)
					var display := original.get_basename()
					display = display.trim_prefix("0123456789_")
					display = display.trim_prefix("-_ ")
					display = display.replace("_", " ").replace("-", " ").capitalize()
					_track_names.append(display)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_selection() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err != OK:
		# Par défaut : Calm Journey (index 2)
		_selected_index = 2
		return
	var saved: String = cfg.get_value(CONFIG_SECTION, "track_file", "")
	if saved == "":
		_selected_index = 0
		return
	var idx := _track_files.find(saved)
	if idx != -1:
		_selected_index = idx
	else:
		_selected_index = 0


func _save_selection() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(CONFIG_SECTION, "track_file", get_selected_file())
	cfg.save(CONFIG_PATH)


# ── Public API ──────────────────────────────────────────────────────────

func get_track_count() -> int:
	return _track_names.size()


func get_track_name(index: int) -> String:
	if index < 0 or index >= _track_names.size():
		return ""
	return _track_names[index]


func get_track_names() -> Array[String]:
	return _track_names.duplicate()


func get_selected_index() -> int:
	return clampi(_selected_index, 0, maxi(0, _track_names.size() - 1))


func get_selected_file() -> String:
	if _track_files.is_empty():
		return ""
	var idx := get_selected_index()
	return _track_files[idx] if idx < _track_files.size() else _track_files[0]


func set_selected_index(index: int) -> void:
	if index < 0 or index >= _track_files.size():
		return
	if index == _selected_index:
		return
	_selected_index = index
	_save_selection()
	music_changed.emit(get_track_name(index))


func rescan() -> void:
	_scan_tracks()
	var saved_file := get_selected_file()
	var idx := _track_files.find(saved_file)
	if idx == -1:
		idx = 0
	_selected_index = idx
