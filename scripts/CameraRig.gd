class_name CameraRig
extends Node3D
## Player stands at the center of the star sphere and looks around, Stellarium-style:
## drag/swipe to pan, scroll wheel or pinch to zoom (change FOV), release-with-motion
## keeps drifting and decays (inertia). Works with mouse (desktop) and touch (mobile).

@export var look_speed := 0.15
@export var min_fov := 15.0   ## zoomed in, for picking out faint/close stars
@export var max_fov := 120.0  ## zoomed out, near-fisheye whole-sky view
@export var zoom_step := 0.9  ## multiplicative per wheel notch, Stellarium-style exponential zoom
@export var button_zoom_step := 0.8  ## bigger jump per on-screen +/- button tap
@export var pitch_limit_deg := 89.0
@export var inertia_friction := 4.0  ## higher = stops sooner

## Manual correction for magnetometer heading error (hard-iron bias, uncalibrated
## sensor, whatever) — nudge with adjust_ar_heading_offset() until the sky matches
## reality. No auto figure-8 calibration flow yet.
@export var ar_heading_offset_deg := 0.0

signal fov_changed(fov: float)

@onready var camera: Camera3D = $Camera3D
@onready var sky_root: Node3D = $"../SkyRoot"

## True (AR mode): orientation comes from the device's accelerometer + magnetometer,
## so pointing the phone at the sky points the app at the same patch of sky —
## Stellarium's core trick. False: manual drag/pinch look, like a map you pan by hand.
var ar_mode_enabled := false

var _dragging := false
var _last_pos := Vector2.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _velocity := Vector2.ZERO  ## screen-space drift, decays after release

var _touches := {}  ## index -> Vector2 position, for single-drag vs pinch-zoom
var _pinch_start_dist := -1.0
var _pinch_start_fov := 0.0

func _unhandled_input(event: InputEvent) -> void:
	if ar_mode_enabled:
		return  # orientation comes from sensors in _process; ignore drag/swipe look
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			_last_pos = event.position
			if event.pressed:
				_velocity = Vector2.ZERO
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / zoom_step)
	elif event is InputEventMouseMotion and _dragging:
		_apply_look_delta(event.position - _last_pos)
		_velocity = event.position - _last_pos
		_last_pos = event.position
	elif event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)

func _process(delta: float) -> void:
	if ar_mode_enabled:
		_apply_ar_orientation()
		return
	if _dragging or _touches.size() > 0:
		return
	if _velocity.length() < 0.05:
		return
	_apply_look_delta(_velocity * delta * 60.0)
	_velocity = _velocity.lerp(Vector2.ZERO, clamp(inertia_friction * delta, 0.0, 1.0))

## Toggles between hand drag/pinch look and device-sensor (AR) look. Switching to
## drag re-seeds _yaw/_pitch from wherever AR left the camera pointed, so there's no
## snap; switching to AR just starts reading sensors next frame.
func set_ar_mode(enabled: bool) -> void:
	if enabled == ar_mode_enabled:
		return
	ar_mode_enabled = enabled
	if not enabled:
		var euler := rotation
		_pitch = clamp(euler.x, deg_to_rad(-pitch_limit_deg), deg_to_rad(pitch_limit_deg))
		_yaw = euler.y
		_velocity = Vector2.ZERO

func adjust_ar_heading_offset(delta_deg: float) -> void:
	ar_heading_offset_deg = fmod(ar_heading_offset_deg + delta_deg, 360.0)

## Orients the rig from the accelerometer (device "up", i.e. -gravity) and magnetometer
## (magnetic north), the same sensor pair real planetarium apps use for AR mode — no
## gyroscope integration drift, because it's read as an absolute orientation every
## frame rather than accumulated.
##
## Godot/Android report the gravity vector pointing away from the ground (up) when the
## device is at rest, magnitude ~9.8; magnetometer reports the ambient magnetic field,
## which points roughly at magnetic north but tilted down into the ground by however
## much local magnetic inclination is. Projecting the magnetometer reading onto the
## plane perpendicular to "up" removes that tilt and leaves compass heading.
##
## Unverified on real hardware (no device available while writing this) — if the sky
## doesn't track the phone correctly, ar_heading_offset_deg is the first thing to try
## adjusting, since sign/axis conventions can vary by platform.
func _apply_ar_orientation() -> void:
	var up_device := Input.get_gravity()
	var mag_device := Input.get_magnetometer()
	if up_device.length() < 0.01 or mag_device.length() < 0.01:
		return  # no sensor data (desktop, or device lacks a magnetometer) — hold last pose
	up_device = up_device.normalized()

	var north_device := (mag_device - up_device * mag_device.dot(up_device))
	if north_device.length() < 0.01:
		return  # magnetometer reading points straight along "up" (degenerate) — skip this frame
	north_device = north_device.normalized()
	if ar_heading_offset_deg != 0.0:
		north_device = north_device.rotated(up_device, deg_to_rad(ar_heading_offset_deg))

	var east_device := north_device.cross(up_device)  # E x N = U convention -> N x U = E

	basis = Basis(east_device, up_device, -north_device)  # -north = "back" so forward(-Z) = north

func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		_velocity = Vector2.ZERO
		if _touches.size() == 2:
			_pinch_start_dist = _current_pinch_dist()
			_pinch_start_fov = camera.fov
		elif _touches.size() == 1:
			_last_pos = event.position
	else:
		_touches.erase(event.index)
		_pinch_start_dist = -1.0
		if _touches.size() == 1:
			_last_pos = _touches.values()[0]

func _on_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	_touches[event.index] = event.position

	if _touches.size() >= 2:
		var dist := _current_pinch_dist()
		if _pinch_start_dist > 0.0:
			_set_fov(_pinch_start_fov * (_pinch_start_dist / dist))
	elif _touches.size() == 1:
		_apply_look_delta(event.position - _last_pos)
		_velocity = event.position - _last_pos
		_last_pos = event.position

func _current_pinch_dist() -> float:
	var pts := _touches.values()
	return pts[0].distance_to(pts[1])

func zoom_in() -> void:
	_zoom_by(button_zoom_step)

func zoom_out() -> void:
	_zoom_by(1.0 / button_zoom_step)

func _zoom_by(factor: float) -> void:
	_set_fov(camera.fov * factor)

func _set_fov(fov: float) -> void:
	camera.fov = clamp(fov, min_fov, max_fov)
	fov_changed.emit(camera.fov)

func _apply_look_delta(delta: Vector2) -> void:
	_yaw += delta.x * look_speed * 0.01
	_pitch = clamp(_pitch + delta.y * look_speed * 0.01, deg_to_rad(-pitch_limit_deg), deg_to_rad(pitch_limit_deg))
	rotation = Vector3(_pitch, _yaw, 0.0)

## Smoothly rotates the rig so the given RA/Dec point ends up centered in view (quiz
## "reveal" pan). Ignored in AR mode, since orientation there comes from the device, not
## _yaw/_pitch. Shortest-path angle interpolation avoids a spurious spin past the pole.
func pan_to_ra_dec(ra_deg: float, dec_deg: float, duration: float = 0.9) -> void:
	if ar_mode_enabled:
		return
	var dir_equatorial := AstroMath.ra_dec_to_vector3(ra_deg, dec_deg, 1.0)
	var dir_world := (sky_root.global_transform.basis * dir_equatorial).normalized()
	var target_euler := Basis.looking_at(dir_world, Vector3.UP).get_euler()
	var target_pitch: float = clamp(target_euler.x, deg_to_rad(-pitch_limit_deg), deg_to_rad(pitch_limit_deg))
	var target_yaw: float = target_euler.y

	_dragging = false
	_velocity = Vector2.ZERO
	var start_pitch := _pitch
	var start_yaw := _yaw
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			_pitch = lerp_angle(start_pitch, target_pitch, t)
			_yaw = lerp_angle(start_yaw, target_yaw, t)
			rotation = Vector3(_pitch, _yaw, 0.0),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Raycasts from the screen point out onto the celestial sphere and returns
## the RA/Dec (in degrees) that the player is looking at. Used for hit-testing taps.
## world_dir is in the Alt/Az world frame (SkyRoot rotates stars into it); un-rotate
## by SkyRoot's basis first to get back to the fixed RA/Dec frame the catalogue uses.
func screen_point_to_ra_dec(screen_pos: Vector2) -> Vector2:
	# project_ray_normal already returns a world-space direction (it factors in the
	# camera's own global transform internally) — multiplying by global_transform.basis
	# again here double-applies the rig's rotation, throwing off every tap once the
	# camera has actually been panned away from its start orientation.
	var world_dir := camera.project_ray_normal(screen_pos)
	var equatorial_dir := sky_root.global_transform.basis.inverse() * world_dir
	return AstroMath.vector3_to_ra_dec(equatorial_dir)
