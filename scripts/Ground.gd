extends MeshInstance3D
## Flat opaque ground plane fixed in world space (unlike SkyRoot, this never rotates —
## the horizon stays put while the sky turns overhead). Occludes the star sphere below
## eye level so the view reads as standing on ground looking up, Stellarium-style,
## instead of floating inside a globe of stars. Real per-star horizon culling (hiding
## stars below altitude 0 for hit-testing/labels) is a later pass; this is the visual
## piece.

@export var radius := 2000.0
@export var depth_below_eye := 1.0  ## camera sits at y=0, so drop the plane slightly beneath it
@export var color := Color(0.05, 0.07, 0.05)
@export var horizon_fade_deg := 15.0  ## how many degrees below the horizon it takes to reach min_alpha, once the screen center is looking at the ground
@export var min_alpha := 0.35  ## floor so the ground never goes fully invisible

@onready var camera: Camera3D = get_node("../CameraRig/Camera3D")

var _mat: StandardMaterial3D

func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)

	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = color
	plane.material = _mat

	mesh = plane
	position = Vector3(0.0, -depth_below_eye, 0.0)

func _process(_delta: float) -> void:
	var forward := -camera.global_transform.basis.z
	if forward.y >= 0.0:
		_mat.albedo_color.a = 1.0  # center of screen above horizon, not looking at ground
		return
	var t: float = clamp(-forward.y / sin(deg_to_rad(horizon_fade_deg)), 0.0, 1.0)
	_mat.albedo_color.a = lerp(1.0, min_alpha, t)
