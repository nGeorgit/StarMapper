extends Control
## Quiz step 1/4: what kind of quiz. Only Constellations exists for now.

func _ready() -> void:
	ConstellationSets.set_active("modern", false)  # background preview default, before any culture is picked
	$VBox/ConstellationsButton.pressed.connect(_on_constellations_pressed)
	$BackButton.pressed.connect(_on_back_pressed)
	var pct := QuizProgress.overall_pct()
	$VBox/ConstellationsButton.text += " — %d%%" % roundi(pct)

func _on_constellations_pressed() -> void:
	GameState.quiz_type = GameState.QuizType.CONSTELLATIONS
	get_tree().change_scene_to_file("res://scenes/SkyMenu.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
