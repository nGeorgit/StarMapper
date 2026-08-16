extends Control
## Quiz step 5/6: which season's sky, at midnight local (00:00) — last stop before
## QuizLengthMenu (and from there Main.tscn), so this is also where Observer's manual
## time gets set; Main.tscn's nodes read Observer in their _ready(), so it must be
## correct before that scene switch happens, not after.

func _ready() -> void:
	$VBox/WinterButton.pressed.connect(_on_pressed.bind(GameState.Season.WINTER))
	$VBox/SummerButton.pressed.connect(_on_pressed.bind(GameState.Season.SUMMER))
	$VBox/CurrentButton.pressed.connect(_on_pressed.bind(GameState.Season.CURRENT))
	$BackButton.pressed.connect(_on_back_pressed)
	_hide_dead_end_seasons()
	_show_progress()

## Hides whichever seasons would leave nothing to quiz for the culture+sky already
## picked, so the player never lands on an empty QuizLengthMenu.
func _hide_dead_end_seasons() -> void:
	var buttons := {
		GameState.Season.WINTER: $VBox/WinterButton,
		GameState.Season.SUMMER: $VBox/SummerButton,
		GameState.Season.CURRENT: $VBox/CurrentButton,
	}
	for season in buttons:
		if QuizAvailability.visible_count(ConstellationSets.constellations, GameState.sky_choice, season) == 0:
			buttons[season].visible = false

## Appends the player's progress % to Winter/Summer (Current isn't a comparable,
## repeatable quiz, so it's left without one -- see QuizProgress).
func _show_progress() -> void:
	for season in [GameState.Season.WINTER, GameState.Season.SUMMER]:
		var btn: Button = $VBox/WinterButton if season == GameState.Season.WINTER else $VBox/SummerButton
		var pct := QuizProgress.season_pct(ConstellationSets.active_id, GameState.difficulty, GameState.sky_choice, season)
		btn.text += " — %d%%" % roundi(pct)

func _on_pressed(season: GameState.Season) -> void:
	GameState.season = season
	Observer.set_manual_time(QuizAvailability.unix_time_for_season(season))
	get_tree().change_scene_to_file("res://scenes/QuizLengthMenu.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/DifficultyMenu.tscn")
