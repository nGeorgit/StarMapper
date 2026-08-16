extends Control
## Quiz step 2/6: which sky. Picked first (right after quiz type), before culture or
## difficulty, since this is meant as a sky-learning tool -- the player's hemisphere
## drives which cultures/constellations they'll actually see, not the other way round.
## North/South are representative mid-latitude views (not the poles — a pole shows
## only circumpolar stars, which is a worse quiz). Location leaves Observer's lat/lon
## alone (it's already "the user's position", or the Thessaloniki placeholder until a
## real GPS source is wired up).

func _ready() -> void:
	ConstellationSets.set_active("modern", false)  # background preview default, before any culture is picked
	$VBox/NorthButton.pressed.connect(_on_pressed.bind(GameState.SkyChoice.NORTH))
	$VBox/SouthButton.pressed.connect(_on_pressed.bind(GameState.SkyChoice.SOUTH))
	$VBox/LocationButton.pressed.connect(_on_pressed.bind(GameState.SkyChoice.LOCATION))
	$BackButton.pressed.connect(_on_back_pressed)
	_show_progress()

## Appends the player's overall progress % (across every culture) to North/South.
## Location isn't a comparable, repeatable quiz, so it's left without one.
func _show_progress() -> void:
	for sky in [GameState.SkyChoice.NORTH, GameState.SkyChoice.SOUTH]:
		var btn: Button = $VBox/NorthButton if sky == GameState.SkyChoice.NORTH else $VBox/SouthButton
		var pct := QuizProgress.sky_pct(sky)
		btn.text += " — %d%%" % roundi(pct)

func _on_pressed(choice: GameState.SkyChoice) -> void:
	GameState.sky_choice = choice
	match choice:
		GameState.SkyChoice.NORTH:
			Observer.lat_deg = GameState.NORTH_LAT_DEG
		GameState.SkyChoice.SOUTH:
			Observer.lat_deg = GameState.SOUTH_LAT_DEG
		GameState.SkyChoice.LOCATION:
			Observer.lat_deg = Observer.DEFAULT_LAT_DEG
			Observer.lon_deg = Observer.DEFAULT_LON_DEG
	get_tree().change_scene_to_file("res://scenes/CultureMenu.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/QuizTypeMenu.tscn")
