extends Control

func _ready() -> void:
	$VBox/ExploreButton.pressed.connect(_on_explore_pressed)
	$VBox/QuizButton.pressed.connect(_on_quiz_pressed)

func _on_explore_pressed() -> void:
	GameState.mode = GameState.Mode.EXPLORE
	Observer.reset_to_default()  # undo whatever a prior quiz's sky/season picks set
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_quiz_pressed() -> void:
	GameState.mode = GameState.Mode.QUIZ
	get_tree().change_scene_to_file("res://scenes/QuizTypeMenu.tscn")
