extends Control
## Quiz step 4/6: difficulty. Controls how much help the sky gives during the quiz —
## applied by StarField/ConstellationLines/StarLabels in Main.tscn by reading
## GameState.difficulty, not here (this screen just records the pick).
##
## Easy:   only constellation stars, with names and constellation lines shown.
## Medium: only constellation stars, no names, no lines.
## Hard:   every star shown, no names, no lines.

func _ready() -> void:
	$VBox/EasyButton.pressed.connect(_on_pressed.bind(GameState.Difficulty.EASY))
	$VBox/MediumButton.pressed.connect(_on_pressed.bind(GameState.Difficulty.MEDIUM))
	$VBox/HardButton.pressed.connect(_on_pressed.bind(GameState.Difficulty.HARD))
	$BackButton.pressed.connect(_on_back_pressed)

func _on_pressed(difficulty: GameState.Difficulty) -> void:
	GameState.difficulty = difficulty
	get_tree().change_scene_to_file("res://scenes/SeasonMenu.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/CultureMenu.tscn")
