extends Control

func _ready() -> void:
	ConstellationSets.set_active("modern", false)  # background preview default, before any culture is picked
	$VBox/ExploreButton.pressed.connect(_on_explore_pressed)
	$VBox/QuizButton.pressed.connect(_on_quiz_pressed)

func _on_explore_pressed() -> void:
	GameState.mode = GameState.Mode.EXPLORE
	Observer.reset_to_default()  # undo whatever a prior quiz's sky/season picks set
	ConstellationSets.set_active(ConstellationSets.default_id())  # undo the "modern" background preview
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_quiz_pressed() -> void:
	GameState.mode = GameState.Mode.QUIZ
	get_tree().change_scene_to_file("res://scenes/QuizTypeMenu.tscn")
