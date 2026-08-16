class_name QuizAvailability
extends RefCounted
## Static, side-effect-free helpers for previewing which constellations would be
## quizzable under a hypothetical sky/season pick, without touching the Observer
## singleton's live lat/lon/time (that only gets committed once the player actually
## presses a SkyMenu/SeasonMenu button). Used by CultureMenu/SeasonMenu to filter
## out dead-end options, and by QuizProgress to score cultures other than the
## currently active one.

static func lat_deg_for_sky(sky: GameState.SkyChoice) -> float:
	match sky:
		GameState.SkyChoice.NORTH:
			return GameState.NORTH_LAT_DEG
		GameState.SkyChoice.SOUTH:
			return GameState.SOUTH_LAT_DEG
		_:
			return Observer.DEFAULT_LAT_DEG

## Midnight local time (00:00) on the season's representative date: the Dec 21/Jun 21
## solstice for Winter/Summer, or today's real date for Current. Moved here from
## SeasonMenu so CultureMenu/SeasonMenu filtering and QuizProgress's scan of other
## cultures all agree with what SeasonMenu will actually commit to Observer.
static func unix_time_for_season(season: GameState.Season) -> float:
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
	return Time.get_unix_time_from_datetime_dict(d)

## Pure equivalent of Observer.altitude_deg(), parameterized instead of reading the
## singleton's current state.
static func altitude_deg(lat_deg: float, lon_deg: float, unix_time: float, ra_deg: float, dec_deg: float) -> float:
	var lst := AstroMath.lst_deg(AstroMath.julian_date_from_unix(unix_time), lon_deg)
	var dir := AstroMath.horizontal_basis(lat_deg, lst) * AstroMath.ra_dec_to_vector3(ra_deg, dec_deg, 1.0)
	return rad_to_deg(asin(clamp(dir.y, -1.0, 1.0)))

## How many of the given constellations would be quizzable (center above
## min_altitude_deg) for a hypothetical sky/season pick.
static func visible_count(constellations: Array, sky: GameState.SkyChoice, season: GameState.Season,
		min_altitude_deg: float = GameState.MIN_VISIBLE_ALTITUDE_DEG, lon_deg: float = Observer.DEFAULT_LON_DEG) -> int:
	var lat := lat_deg_for_sky(sky)
	var t := unix_time_for_season(season)
	var n := 0
	for c in constellations:
		var center: Vector2 = c["center"] if c.has("center") else AstroMath.constellation_center(c["segments"])
		if altitude_deg(lat, lon_deg, t, center.x, center.y) >= min_altitude_deg:
			n += 1
	return n

## Loads a culture's constellations straight from disk, independent of whichever set
## ConstellationSets currently has active (mirrors ConstellationSets._load_set without
## mutating the singleton). Returns [] if the culture id doesn't exist.
static func load_culture_raw(culture_id: String) -> Array:
	var path := ConstellationSets.SETS_DIR + culture_id + ".json"
	if not FileAccess.file_exists(path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		return []
	var constellations: Array = parsed["constellations"]
	for c in constellations:
		c["center"] = AstroMath.constellation_center(c["segments"])
	return constellations
