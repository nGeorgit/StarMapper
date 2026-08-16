extends Control
## Quiz step 1/4: what kind of quiz. Only Constellations exists for now.

func _ready() -> void:
	$VBox/ConstellationsButton.pressed.connect(_on_constellations_pressed)
	$BackButton.pressed.connect(_on_back_pressed)

func _on_constellations_pressed() -> void:
	GameState.quiz_type = GameState.QuizType.CONSTELLATIONS
	get_tree().change_scene_to_file("res://scenes/DifficultyMenu.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
