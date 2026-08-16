extends Label
## Shows the observer's date/time and a human-readable location name (never raw lat/lon
## coordinates) in the corner of the sky view.
##
## Explore: always on. Quiz: Easy/Medium (matches every other "how much help" visual);
## Hard hides it, same as the star names/constellation lines it's drawn alongside.

@export var update_interval_sec := 1.0

var _accum := 0.0

func _ready() -> void:
	if GameState.mode == GameState.Mode.QUIZ and GameState.difficulty == GameState.Difficulty.HARD:
		visible = false
		return
	_refresh()

func _process(delta: float) -> void:
	_accum += delta
	if _accum < update_interval_sec:
		return
	_accum = 0.0
	_refresh()

func _refresh() -> void:
	var dt := Time.get_datetime_dict_from_unix_time(int(Observer.current_unix_time()))
	var date_str := "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	var time_str := "%02d:%02d" % [dt["hour"], dt["minute"]]
	text = "%s\n%s   %s" % [_location_label(), date_str, time_str]

## A human-readable stand-in for lat/lon -- Observer only tracks raw coordinates
## (no location-name field), so North/South map to the representative-sky labels
## SkyMenu already shows the player, and "My Position" falls back to the placeholder
## GPS location (Thessaloniki) until a real device-location source is wired up.
func _location_label() -> String:
	if GameState.mode == GameState.Mode.QUIZ:
		match GameState.sky_choice:
			GameState.SkyChoice.NORTH:
				return "Northern Sky"
			GameState.SkyChoice.SOUTH:
				return "Southern Sky"
	return "Thessaloniki"
