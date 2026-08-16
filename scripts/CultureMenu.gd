extends Control
## Quiz step 3/6: which constellation culture (Stellarium skyculture). Filtered by the
## sky already picked -- a culture that has nothing visible in that hemisphere (in any
## season) is left off the list entirely, since there'd be nothing to quiz.

func _ready() -> void:
	ConstellationSets.set_active("modern", false)  # background preview default, until a culture below is picked
	var list: VBoxContainer = $ScrollContainer/List
	for culture in ConstellationSets.available:
		var raw := QuizAvailability.load_culture_raw(culture["id"])
		if not QuizAvailability.has_any_visible(raw, GameState.sky_choice):
			continue
		var btn := Button.new()
		btn.mouse_filter = Control.MOUSE_FILTER_PASS  # let touch-drag bubble to ScrollContainer for scrolling
		btn.custom_minimum_size = Vector2(0, 109)
		btn.add_theme_font_size_override("font_size", 24)
		var pct := QuizProgress.culture_pct(culture["id"], GameState.sky_choice)
		btn.text = "%s (%d constellations) — %d%%" % [culture["name"], culture["count"], roundi(pct)]
		btn.pressed.connect(_on_culture_pressed.bind(culture["id"]))
		list.add_child(btn)
	$BackButton.pressed.connect(_on_back_pressed)

func _on_culture_pressed(id: String) -> void:
	ConstellationSets.set_active(id)
	get_tree().change_scene_to_file("res://scenes/DifficultyMenu.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SkyMenu.tscn")
