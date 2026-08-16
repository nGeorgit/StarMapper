extends Control
## Quiz step 3/4: which sky. North/South are representative mid-latitude views (not
## the poles — a pole shows only circumpolar stars, which is a worse quiz). Location
## leaves Observer's lat/lon alone (it's already "the user's position", or the
## Thessaloniki placeholder until a real GPS source is wired up).

const NORTH_LAT_DEG := 60.0
const SOUTH_LAT_DEG := -60.0

func _ready() -> void:
	$VBox/NorthButton.pressed.connect(_on_pressed.bind(GameState.SkyChoice.NORTH))
	$VBox/SouthButton.pressed.connect(_on_pressed.bind(GameState.SkyChoice.SOUTH))
	$VBox/LocationButton.pressed.connect(_on_pressed.bind(GameState.SkyChoice.LOCATION))
	$BackButton.pressed.connect(_on_back_pressed)

func _on_pressed(choice: GameState.SkyChoice) -> void:
	GameState.sky_choice = choice
	match choice:
		GameState.SkyChoice.NORTH:
			Observer.lat_deg = NORTH_LAT_DEG
		GameState.SkyChoice.SOUTH:
			Observer.lat_deg = SOUTH_LAT_DEG
		GameState.SkyChoice.LOCATION:
			Observer.lat_deg = Observer.DEFAULT_LAT_DEG
			Observer.lon_deg = Observer.DEFAULT_LON_DEG
	get_tree().change_scene_to_file("res://scenes/SeasonMenu.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/DifficultyMenu.tscn")
