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

func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	plane.material = mat

	mesh = plane
	position = Vector3(0.0, -depth_below_eye, 0.0)
