extends Control
## Quiz step 4/6: difficulty. Controls how much help the sky gives during the quiz —
## applied by StarField/ConstellationLines/StarLabels in Main.tscn by reading
## GameState.difficulty, not here (this screen just records the pick).
##
## Easy:   every star shown, with names and constellation lines shown.
## Medium: only constellation stars, no names, no lines.
## Hard:   every star shown, no names, no lines.

func _ready() -> void:
	$VBox/EasyButton.pressed.connect(_on_pressed.bind(GameState.Difficulty.EASY))
	$VBox/MediumButton.pressed.connect(_on_pressed.bind(GameState.Difficulty.MEDIUM))
	$VBox/HardButton.pressed.connect(_on_pressed.bind(GameState.Difficulty.HARD))
	$BackButton.pressed.connect(_on_back_pressed)
	_show_progress()

## Appends the player's progress % (for the culture+sky already picked) to each
## difficulty button.
func _show_progress() -> void:
	var buttons := {
		GameState.Difficulty.EASY: $VBox/EasyButton,
		GameState.Difficulty.MEDIUM: $VBox/MediumButton,
		GameState.Difficulty.HARD: $VBox/HardButton,
	}
	for difficulty in buttons:
		var pct := QuizProgress.difficulty_pct(ConstellationSets.active_id, difficulty, GameState.sky_choice)
		buttons[difficulty].text += " — %d%%" % roundi(pct)

func _on_pressed(difficulty: GameState.Difficulty) -> void:
	GameState.difficulty = difficulty
	get_tree().change_scene_to_file("res://scenes/SeasonMenu.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/CultureMenu.tscn")
