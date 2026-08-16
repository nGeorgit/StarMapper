extends Node
## Autoload: who's looking at the sky, from where, and when. This is the single
## source of truth that SkyRoot reads each update to rotate the RA/Dec star sphere
## into the observer's actual Alt/Az view — the thing that makes the app match what's
## overhead right now instead of an arbitrary free-floating star globe.
##
## lat/lon default to a placeholder (Thessaloniki); no GPS integration yet (Godot has no
## built-in location API — would need a platform plugin), so wire set_location() up
## to a location picker or device GPS plugin when that's ready. Time defaults to the
## real system clock.

signal location_changed

const DEFAULT_LAT_DEG := 40.6401  ## Thessaloniki
const DEFAULT_LON_DEG := 22.9444

@export var lat_deg := DEFAULT_LAT_DEG
@export var lon_deg := DEFAULT_LON_DEG

var use_system_clock := true
var manual_unix_time := 0.0  ## only used when use_system_clock is false

func set_location(lat: float, lon: float) -> void:
	lat_deg = clamp(lat, -90.0, 90.0)
	lon_deg = wrapf(lon, -180.0, 180.0)
	location_changed.emit()

## Undoes whatever a quiz round's sky/season picks did to lat/lon/time, so Explore
## mode (and a fresh Quiz run) always starts from "here, right now" again.
func reset_to_default() -> void:
	lat_deg = DEFAULT_LAT_DEG
	lon_deg = DEFAULT_LON_DEG
	use_system_clock = true
	manual_unix_time = 0.0
	location_changed.emit()

func set_manual_time(unix_time: float) -> void:
	use_system_clock = false
	manual_unix_time = unix_time

func use_real_time() -> void:
	use_system_clock = true

func current_unix_time() -> float:
	return Time.get_unix_time_from_system() if use_system_clock else manual_unix_time

func local_sidereal_time_deg() -> float:
	var jd := AstroMath.julian_date_from_unix(current_unix_time())
	return AstroMath.lst_deg(jd, lon_deg)

## The rotation SkyRoot applies: RA/Dec sphere -> this observer's Alt/Az frame, right now.
func horizontal_basis() -> Basis:
	return AstroMath.horizontal_basis(lat_deg, local_sidereal_time_deg())

## Altitude (degrees above horizon, negative if below) of a fixed RA/Dec point right now.
## Used to filter which constellations are actually up for the current observer/time.
func altitude_deg(ra_deg: float, dec_deg: float) -> float:
	var dir := horizontal_basis() * AstroMath.ra_dec_to_vector3(ra_deg, dec_deg, 1.0)
	return rad_to_deg(asin(clamp(dir.y, -1.0, 1.0)))
