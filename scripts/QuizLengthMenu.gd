extends Control
## Quiz step 6/6: how many constellations to quiz -- 30/50/100% of what's actually
## visible for the culture+sky+season+difficulty already picked. Buttons show the
## real count, not the percentage, plus the player's best score at that length if
## they've attempted it before. Observer's lat/lon/time are already committed by
## SkyMenu/SeasonMenu at this point, so the pool computed here is exactly what
## GameManager will draw from once Main.tscn loads.

func _ready() -> void:
	var pool_size := _visible_pool_size()
	_setup_button($VBox/ThirtyButton, GameState.QuizLength.THIRTY, _tier_count(pool_size, 0.30))
	_setup_button($VBox/FiftyButton, GameState.QuizLength.FIFTY, _tier_count(pool_size, 0.50))
	_setup_button($VBox/HundredButton, GameState.QuizLength.HUNDRED, pool_size)
	$BackButton.pressed.connect(_on_back_pressed)

func _visible_pool_size() -> int:
	var n := 0
	for c in ConstellationSets.constellations:
		var center: Vector2 = AstroMath.constellation_center(c["segments"])
		if Observer.altitude_deg(center.x, center.y) >= GameState.MIN_VISIBLE_ALTITUDE_DEG:
			n += 1
	return n

func _tier_count(pool_size: int, fraction: float) -> int:
	return maxi(1, roundi(pool_size * fraction)) if pool_size > 0 else 0

func _setup_button(btn: Button, length: GameState.QuizLength, count: int) -> void:
	var text := "%d constellations" % count
	var best := QuizProgress.get_best(ConstellationSets.active_id, GameState.difficulty, GameState.sky_choice, GameState.season, length)
	if not best.is_empty():
		text += " — best %d/%d" % [best["best_correct"], best["best_total"]]
	btn.text = text
	btn.pressed.connect(_on_pressed.bind(length, count))

func _on_pressed(length: GameState.QuizLength, count: int) -> void:
	GameState.quiz_length = length
	GameState.quiz_round_count = count
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SeasonMenu.tscn")
