extends Node
## Dev-only, temporary: prints what a tap landed on (nearest catalog star) plus where
## that RA/Dec direction currently lands in the Milky Way source photo (eso0932a.tif,
## 6000x3000), for checking/refining the galactic-coordinate calibration against real
## stars. Mirrors the UV math in shaders/milkyway_sky.gdshader exactly -- keep both in
## sync if either changes. Remove this script + its node from Main.tscn once done.

@export var match_radius_deg := 3.0

@onready var camera_rig: CameraRig = $"../CameraRig"
@onready var star_field: StarField = $"../SkyRoot/StarField"

var _press_pos := Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
		else:
			_log_tap(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_press_pos = event.position
		else:
			_log_tap(event.position)

func _log_tap(screen_pos: Vector2) -> void:
	if _press_pos.distance_to(screen_pos) > 20.0:
		return  # was a drag, not a tap

	var ra_dec := camera_rig.screen_point_to_ra_dec(screen_pos)
	var ra: float = ra_dec.x
	var dec: float = ra_dec.y

	var nearest_name := "(no catalog star within %.1f deg)" % match_radius_deg
	var nearest_dist := INF
	for s: Dictionary in star_field.loaded_stars:
		var d := AstroMath.angular_separation_deg(ra, dec, s["ra"], s["dec"])
		if d < nearest_dist:
			nearest_dist = d
			if d <= match_radius_deg:
				nearest_name = "%s (mag %.2f, %.2f deg away)" % [s.get("name", "unnamed"), s["mag"], d]

	# Must mirror shaders/milkyway_sky.gdshader's calibration rotation (+ MIRROR flip)
	# exactly, or this tool's printed pixel silently drifts out of sync with the screen.
	const MIRROR := true
	const IMG_ROW0 := Vector3(0.002808, 0.455148, 0.890415)
	const IMG_ROW1 := Vector3(-0.876924, 0.429086, -0.216565)
	const IMG_ROW2 := Vector3(-0.480632, -0.780211, 0.400337)

	var dir := AstroMath.ra_dec_to_vector3(ra, dec, 1.0)
	var img := Vector3(dir.dot(IMG_ROW0), dir.dot(IMG_ROW1), dir.dot(IMG_ROW2))
	var v: float = clamp(acos(clamp(img.y, -1.0, 1.0)) / PI, 0.0, 1.0)
	var u: float = fmod(atan2(img.z, img.x) / TAU + 1.0, 1.0)
	if MIRROR:
		u = fmod(1.0 - u, 1.0)

	var col := 0 if u < 0.5 else 1
	var row := 0 if v < 0.5 else 1
	var local_u := fmod(u * 2.0, 1.0)
	var local_v := fmod(v * 2.0, 1.0)
	var full_px := (col * 3000.0) + local_u * 3000.0
	var full_py := (row * 1500.0) + local_v * 1500.0

	print("TAP screen=%s -> ra=%.3f dec=%.3f | nearest star: %s" % [screen_pos, ra, dec, nearest_name])
	print("    milkyway tile=c%d_r%d local_uv=(%.4f, %.4f) -> full-image(6000x3000) pixel=(%.0f, %.0f)" % [col, row, local_u, local_v, full_px, full_py])
