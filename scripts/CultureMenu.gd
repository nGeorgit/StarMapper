extends Control
## Quiz step 3/6: which constellation culture (Stellarium skyculture). Filtered by the
## sky already picked -- a culture that has nothing visible in that hemisphere (in any
## season) is left off the list entirely, since there'd be nothing to quiz.
##
## The full culture list is long (60+) and mostly repeats a handful of traditions under
## different names/eras (5 Chinese sets, 8 Modern variants, etc). So the top screen is a
## 2-column, 3-row icon grid: one tile per broad tradition (grouped by id prefix, e.g. "greek_*") that
## has 2+ entries at MIN_MAIN_COUNT+ constellations, plus one "Extras" tile for everything
## that doesn't fit a tile -- lone traditions (japanese, korean, ...) and every
## below-threshold culture, including below-threshold members of a tile's own tradition
## (e.g. chinese_manchu joins the Chinese tile instead of sitting in Extras).
## Picking a tile opens the same flat list the old single-menu used, scoped to that group.

const MIN_MAIN_COUNT := 30

## Fixed display order, largest tradition first. `prefix` must match the part of a
## culture id before its first "_" (or the whole id, for prefix-less ids like "modern").
const CATEGORY_DEFS := [
	{"prefix": "modern", "name": "Modern", "icon": "res://assets/culture_icons/modern_glyph.png"},
	{"prefix": "chinese", "name": "Chinese", "icon": "res://assets/culture_icons/chinese_glyph.png"},
	{"prefix": "greek", "name": "Greek", "icon": "res://assets/culture_icons/greek_glyph.png"},
	{"prefix": "arabic", "name": "Arabic", "icon": "res://assets/culture_icons/arabic_glyph.png"},
	{"prefix": "babylonian", "name": "Babylonian", "icon": "res://assets/culture_icons/babylonian_glyph.png"},
]

const TILE_ICON_SIZE := 320.0

var _categories: Dictionary = {}  ## prefix -> { "name", "icon", "cultures": [culture, ...] }
var _extras: Array = []
var _in_grid := true

func _ready() -> void:
	ConstellationSets.set_active("modern", false)  # background preview default, until a culture below is picked
	_build_groups()
	_populate_grid()
	$BackButton.pressed.connect(_on_back_pressed)

func _culture_prefix(id: String) -> String:
	return id.split("_")[0]

## Splits every visible culture into tradition groups (2+ main-tier entries sharing a
## CATEGORY_DEFS prefix) vs. everything left over (_extras).
func _build_groups() -> void:
	var main_by_prefix: Dictionary = {}  ## prefix -> [culture, ...], MIN_MAIN_COUNT+ only
	var below_threshold: Array = []

	for culture in ConstellationSets.available:
		var raw := QuizAvailability.load_culture_raw(culture["id"])
		if not QuizAvailability.has_any_visible(raw, GameState.sky_choice):
			continue
		if culture["count"] >= MIN_MAIN_COUNT:
			var prefix := _culture_prefix(culture["id"])
			if not main_by_prefix.has(prefix):
				main_by_prefix[prefix] = []
			main_by_prefix[prefix].append(culture)
		else:
			below_threshold.append(culture)

	var def_by_prefix: Dictionary = {}
	for def in CATEGORY_DEFS:
		def_by_prefix[def["prefix"]] = def

	for prefix in main_by_prefix:
		var members: Array = main_by_prefix[prefix]
		if def_by_prefix.has(prefix) and members.size() >= 2:
			var def: Dictionary = def_by_prefix[prefix]
			_categories[prefix] = {"name": def["name"], "icon": def["icon"], "cultures": members}
		else:
			_extras.append_array(members)

	for culture in below_threshold:
		var prefix := _culture_prefix(culture["id"])
		if _categories.has(prefix):
			_categories[prefix]["cultures"].append(culture)
		else:
			_extras.append(culture)

func _populate_grid() -> void:
	var grid: GridContainer = $Grid
	for def in CATEGORY_DEFS:
		if _categories.has(def["prefix"]):
			grid.add_child(_make_tile(def["name"], def["icon"], _categories[def["prefix"]]["cultures"], _on_category_pressed.bind(def["prefix"])))
	if not _extras.is_empty():
		grid.add_child(_make_tile("Extras", "", _extras, _on_extras_pressed))

func _make_tile(title: String, icon_path: String, cultures: Array, on_pressed: Callable) -> Button:
	var btn := Button.new()
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.custom_minimum_size = Vector2(0, 420)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(on_pressed)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	btn.add_child(vbox)

	if icon_path != "":
		var icon_rect := TextureRect.new()
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.texture = load(icon_path)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(TILE_ICON_SIZE, TILE_ICON_SIZE)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon_rect)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	var pct := _avg_pct(cultures)
	label.text = "%s (%d)\n%d%%" % [title, cultures.size(), roundi(pct)]
	vbox.add_child(label)

	return btn

func _avg_pct(cultures: Array) -> float:
	if cultures.is_empty():
		return 0.0
	var total := 0.0
	for culture in cultures:
		total += QuizProgress.culture_pct(culture["id"], GameState.sky_choice)
	return total / cultures.size()

func _make_culture_button(culture: Dictionary) -> Button:
	var btn := Button.new()
	btn.mouse_filter = Control.MOUSE_FILTER_PASS  # let touch-drag bubble to ScrollContainer for scrolling
	btn.custom_minimum_size = Vector2(0, 109)
	btn.add_theme_font_size_override("font_size", 24)
	var pct := QuizProgress.culture_pct(culture["id"], GameState.sky_choice)
	btn.text = "%s (%d constellations) — %d%%" % [culture["name"], culture["count"], roundi(pct)]
	btn.pressed.connect(_on_culture_pressed.bind(culture["id"]))
	return btn

func _show_sublist(title: String, cultures: Array) -> void:
	_in_grid = false
	$Grid.visible = false
	$ScrollContainer.visible = true
	$TitleBox/Title.text = title
	var list: VBoxContainer = $ScrollContainer/List
	for child in list.get_children():
		child.queue_free()
	for culture in cultures:
		list.add_child(_make_culture_button(culture))

func _on_category_pressed(prefix: String) -> void:
	_show_sublist(_categories[prefix]["name"], _categories[prefix]["cultures"])

func _on_extras_pressed() -> void:
	_show_sublist("Extras", _extras)

func _on_culture_pressed(id: String) -> void:
	ConstellationSets.set_active(id)
	get_tree().change_scene_to_file("res://scenes/DifficultyMenu.tscn")

func _on_back_pressed() -> void:
	if _in_grid:
		get_tree().change_scene_to_file("res://scenes/SkyMenu.tscn")
		return
	_in_grid = true
	$ScrollContainer.visible = false
	$Grid.visible = true
	$TitleBox/Title.text = "Culture"
