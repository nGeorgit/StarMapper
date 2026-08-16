extends Control
## Quiz step 4/4: which season's sky, at midnight local (00:00) — last stop before
## Main.tscn actually loads, so this is also where Observer's manual time gets set;
## Main.tscn's nodes read Observer in their _ready(), so it must be correct before
## the scene switch happens, not after.

func _ready() -> void:
	$VBox/WinterButton.pressed.connect(_on_pressed.bind(GameState.Season.WINTER))
	$VBox/SummerButton.pressed.connect(_on_pressed.bind(GameState.Season.SUMMER))
	$VBox/CurrentButton.pressed.connect(_on_pressed.bind(GameState.Season.CURRENT))
	$BackButton.pressed.connect(_on_back_pressed)

func _on_pressed(season: GameState.Season) -> void:
	GameState.season = season
	Observer.set_manual_time(Time.get_unix_time_from_datetime_dict(_midnight_date_dict(season)))
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _midnight_date_dict(season: GameState.Season) -> Dictionary:
	var today := Time.get_datetime_dict_from_system()
	var d := {"year": today["year"], "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0}
	match season:
		GameState.Season.WINTER:
			d["month"] = 12
			d["day"] = 21
		GameState.Season.SUMMER:
			d["month"] = 6
			d["day"] = 21
		GameState.Season.CURRENT:
			d["month"] = today["month"]
			d["day"] = today["day"]
	return d

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SkyMenu.tscn")
