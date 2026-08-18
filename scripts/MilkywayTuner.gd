extends Node
## Dev-only, temporary: manual live tuning for the Milky Way texture's calibration
## rotation (shaders/milkyway_sky.gdshader's IMG_ROW0/1/2), for when clicking specific
## stars in the photo isn't reliable enough on its own.
##
## Arrow keys pan the texture screen-relative (rotated around the camera's current
## up/right axis, converted into the equatorial frame the calibration operates in);
## Q/E roll it around a PIVOT point instead of the view axis -- click/tap anywhere to
## set the pivot to that point (e.g. click the star you're aligning against, so Q/E
## rotates the texture around it instead of around screen center). Pivot defaults to
## the camera's current view center until you click. F toggles a horizontal mirror
## (starts ON -- see shaders/milkyway_sky.gdshader's MIRROR comment for why rotation
## alone can never fix a genuinely mirrored source photo). Hold Shift for a fine step.
## Every adjustment prints the resulting IMG_ROW0/1/2 and MIRROR state -- once it looks
## right on screen, paste the last printed block into shaders/milkyway_sky.gdshader's
## uniform defaults AND scripts/DebugClickLogger.gd's matching consts, then remove this
## script + its node from Main.tscn.

@export var coarse_step_deg := 1.0
@export var fine_step_deg := 0.05
@export var tap_move_tolerance_px := 20.0  ## press-release drift under this counts as a pivot-set tap, not a camera drag

@onready var camera_rig: CameraRig = $"../CameraRig"
@onready var sky_root: Node3D = $"../SkyRoot"
@onready var _material: ShaderMaterial = $"../WorldEnvironment".environment.sky.sky_material

## Starting point: current finalized calibration (must match
## shaders/milkyway_sky.gdshader's IMG_ROW0/1/2 defaults, else this overwrites them
## with a stale basis the moment the scene loads). Columns, matching the shader's rows.
var _basis := Basis(
	Vector3(0.002808, -0.876924, -0.480632),
	Vector3(0.455148, 0.429086, -0.780211),
	Vector3(0.890415, -0.216565, 0.400337)
)

var _pivot_eq := Vector3.ZERO  ## ZERO = unset, falls back to current view center
var _press_pos := Vector2.ZERO
var _mirror := true

func _ready() -> void:
	_push()
	_print()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
		else:
			_maybe_set_pivot(event.position)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press_pos = event.position
		else:
			_maybe_set_pivot(event.position)
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F:
		_mirror = not _mirror
		_push()
		_print()
		return
	var step := deg_to_rad(fine_step_deg if event.shift_pressed else coarse_step_deg)

	# Rotation axes come from the camera's CURRENT screen-space directions, converted
	# into the equatorial frame the calibration basis operates on -- same un-rotation
	# CameraRig.gd's screen_point_to_ra_dec and the shader's equatorial_from_world use.
	var world_to_eq := sky_root.global_transform.basis.inverse()
	var cam_basis := camera_rig.camera.global_transform.basis
	var right_eq := (world_to_eq * cam_basis.x).normalized()
	var up_eq := (world_to_eq * cam_basis.y).normalized()
	var forward_eq := (world_to_eq * -cam_basis.z).normalized()
	var pivot_eq := forward_eq if _pivot_eq.is_zero_approx() else _pivot_eq

	var axis: Vector3
	var angle := 0.0
	match event.keycode:
		KEY_LEFT:
			axis = up_eq; angle = -step
		KEY_RIGHT:
			axis = up_eq; angle = step
		KEY_UP:
			axis = right_eq; angle = step
		KEY_DOWN:
			axis = right_eq; angle = -step
		KEY_Q:
			axis = pivot_eq; angle = -step
		KEY_E:
			axis = pivot_eq; angle = step
		_:
			return

	# Right-multiply: axis/angle rotate the EQUATORIAL (input) side, before _basis maps
	# it to image space. That's what makes a direction an eigenvector of the adjustment
	# -- necessary for Q/E to hold the pivot's image fixed while everything spins around
	# it. (Left-multiplying rotates the image/output side instead, which would need the
	# axis expressed in image-space coordinates, not equatorial -- a frame mismatch that
	# was the earlier bug: the pivot visibly moved instead of staying put.)
	_basis = _basis * Basis(axis, angle)
	_push()
	_print()

func _maybe_set_pivot(release_pos: Vector2) -> void:
	if _press_pos.distance_to(release_pos) > tap_move_tolerance_px:
		return  # was a camera drag, not a pivot-set tap
	var world_dir := camera_rig.camera.project_ray_normal(release_pos)
	_pivot_eq = (sky_root.global_transform.basis.inverse() * world_dir).normalized()
	var ra_dec := camera_rig.screen_point_to_ra_dec(release_pos)
	print("MilkywayTuner: pivot set at screen=%s -> ra=%.3f dec=%.3f" % [release_pos, ra_dec.x, ra_dec.y])

func _push() -> void:
	_material.set_shader_parameter("IMG_ROW0", Vector3(_basis.x.x, _basis.y.x, _basis.z.x))
	_material.set_shader_parameter("IMG_ROW1", Vector3(_basis.x.y, _basis.y.y, _basis.z.y))
	_material.set_shader_parameter("IMG_ROW2", Vector3(_basis.x.z, _basis.y.z, _basis.z.z))
	_material.set_shader_parameter("MIRROR", _mirror)

func _print() -> void:
	var r0 := Vector3(_basis.x.x, _basis.y.x, _basis.z.x)
	var r1 := Vector3(_basis.x.y, _basis.y.y, _basis.z.y)
	var r2 := Vector3(_basis.x.z, _basis.y.z, _basis.z.z)
	print("uniform bool MIRROR = %s;" % ("true" if _mirror else "false"))
	print("uniform vec3 IMG_ROW0 = vec3(%.6f, %.6f, %.6f);" % [r0.x, r0.y, r0.z])
	print("uniform vec3 IMG_ROW1 = vec3(%.6f, %.6f, %.6f);" % [r1.x, r1.y, r1.z])
	print("uniform vec3 IMG_ROW2 = vec3(%.6f, %.6f, %.6f);" % [r2.x, r2.y, r2.z])
