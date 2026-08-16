extends Control
## Quiz step 3/6: which constellation culture (Stellarium skyculture). Filtered by the
## sky already picked -- a culture that has nothing visible in that hemisphere (in any
## season) is left off the list entirely, since there'd be nothing to quiz.

func _ready() -> void:
	var list: VBoxContainer = $ScrollContainer/List
	for culture in ConstellationSets.available:
		var raw := QuizAvailability.load_culture_raw(culture["id"])
		if not _has_any_season(raw):
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 64)
		var pct := QuizProgress.culture_completion_pct(culture["id"])
		btn.text = "%s (%d constellations) — %d%% complete" % [culture["name"], culture["count"], roundi(pct)]
		btn.pressed.connect(_on_culture_pressed.bind(culture["id"]))
		list.add_child(btn)
	$BackButton.pressed.connect(_on_back_pressed)

func _has_any_season(raw: Array) -> bool:
	for season in [GameState.Season.WINTER, GameState.Season.SUMMER, GameState.Season.CURRENT]:
		if QuizAvailability.visible_count(raw, GameState.sky_choice, season) > 0:
			return true
	return false

func _on_culture_pressed(id: String) -> void:
	ConstellationSets.set_active(id)
	get_tree().change_scene_to_file("res://scenes/DifficultyMenu.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SkyMenu.tscn")
