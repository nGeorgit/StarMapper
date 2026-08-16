extends Node
## Autoload singleton: owns which constellation set (Stellarium skyculture) is active,
## loads its data, and persists the choice as the startup default. Loads before any
## scene node's _ready() runs (autoload init order), so ConstellationLines/StarField
## can read `constellations`/`hip_ids` synchronously in their own _ready().
##
## Data layout (built by tools/parse_stellarium_data.py):
##   res://data/constellation_sets/manifest.json -- [{ "id", "name", "region", "count" }, ...]
##   res://data/constellation_sets/<id>.json      -- { "id", "hips": [...], "constellations": [...] }

const MANIFEST_PATH := "res://data/constellation_sets/manifest.json"
const SETS_DIR := "res://data/constellation_sets/"
const CONFIG_PATH := "user://settings.cfg"
const DEFAULT_SET_ID := "modern_iau"  ## western/IAU 88 -- matches the game's original single set

signal set_changed

var available: Array = []  ## [{ "id", "name", "region", "count" }, ...], sorted by name
var active_id: String = DEFAULT_SET_ID
var constellations: Array = []  ## [{ "id", "name", "segments" }, ...] for the active set
var hip_ids: Dictionary = {}  ## HIP (int) -> true, stars that anchor the active set's lines

func _ready() -> void:
	_load_manifest()
	var saved_id := _read_default_from_config()
	_load_set(saved_id if saved_id != "" else DEFAULT_SET_ID)

## Switches the active set, reloads its data, and saves it as the new startup default.
func set_active(id: String) -> void:
	if id == active_id:
		return
	if not _load_set(id):
		return
	_write_default_to_config(id)
	set_changed.emit()

func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("ConstellationSets: %s not found, run tools/parse_stellarium_data.py first" % MANIFEST_PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	available = parsed if parsed != null else []

## Loads res://data/constellation_sets/<id>.json into constellations/hip_ids.
## Returns false (leaving the previous set in place) if the file is missing/invalid.
func _load_set(id: String) -> bool:
	var path := SETS_DIR + id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("ConstellationSets: %s not found" % path)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("ConstellationSets: failed to parse %s" % path)
		return false

	active_id = id
	constellations = parsed["constellations"]
	hip_ids.clear()
	for hip in parsed["hips"]:
		hip_ids[hip] = true
	return true

func _read_default_from_config() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return ""
	return cfg.get_value("constellations", "active_set", "")

func _write_default_to_config(id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)  ## ok to fail (file may not exist yet); keeps any other sections
	cfg.set_value("constellations", "active_set", id)
	cfg.save(CONFIG_PATH)
