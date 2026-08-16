extends MultiMeshInstance3D
## Azimuthal reference grid: circles of constant altitude and meridians of constant
## azimuth, drawn fixed in world space. Unlike ConstellationLines (which lives under
## SkyRoot and rotates with sidereal time), this sits at Main's root next to Ground --
## world space already IS the observer's local Alt/Az frame (see
## AstroMath.horizontal_basis), so the grid never needs to move.
##
## Explore: always on. Quiz: Easy/Medium (matches every other "how much help" visual);
## Hard hides it, same as the star names/constellation lines it's drawn alongside.

@export var line_color := Color(0.35, 0.55, 0.4, 0.35)
@export var line_radius := 0.35
@export var radial_segments := 5
@export var alt_step_deg := 15.0  ## rings at 15, 30, 45, 60, 75 (90 is a single point: the zenith)
@export var az_step_deg := 30.0  ## meridians every 30 degrees (12 of them)
@export var arc_step_deg := 5.0  ## how finely each ring/meridian curve is subdivided
@export var grid_radius := AstroMath.SKY_RADIUS * 0.998  ## just inside the star sphere/constellation lines
@export var reference_fov := 60.0  ## fov at which line_radius renders at its literal value

@onready var camera_rig: CameraRig = $"../CameraRig"

var _mat: ShaderMaterial
var _ref_tan := 1.0

func _ready() -> void:
	if GameState.mode == GameState.Mode.QUIZ and GameState.difficulty == GameState.Difficulty.HARD:
		return
	_ref_tan = tan(deg_to_rad(reference_fov) * 0.5)
	_build()
	if camera_rig:
		camera_rig.fov_changed.connect(_on_fov_changed)
		_on_fov_changed(camera_rig.camera.fov)

func _build() -> void:
	var pairs: Array = []

	var alt_rings := int(90.0 / alt_step_deg)
	var arc_steps := int(360.0 / arc_step_deg)
	for r in range(1, alt_rings):
		var alt: float = r * alt_step_deg
		for s in range(arc_steps):
			var az_a: float = s * arc_step_deg
			var az_b: float = (s + 1) * arc_step_deg
			pairs.append([AstroMath.alt_az_to_vector3(alt, az_a, grid_radius), AstroMath.alt_az_to_vector3(alt, az_b, grid_radius)])

	var meridians := int(360.0 / az_step_deg)
	var alt_steps := int(90.0 / arc_step_deg)
	for m in range(meridians):
		var az: float = m * az_step_deg
		for s in range(alt_steps):
			var alt_a: float = s * arc_step_deg
			var alt_b: float = (s + 1) * arc_step_deg
			pairs.append([AstroMath.alt_az_to_vector3(alt_a, az, grid_radius), AstroMath.alt_az_to_vector3(alt_b, az, grid_radius)])

	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = radial_segments
	cyl.rings = 0
	cyl.cap_top = false
	cyl.cap_bottom = false

	var shader := Shader.new()
	shader.code = """
		shader_type spatial;
		render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;
		uniform float fov_scale = 1.0;
		void vertex() {
			VERTEX.x *= fov_scale;
			VERTEX.z *= fov_scale;
		}
		void fragment() {
			ALBEDO = COLOR.rgb;
			ALPHA = COLOR.a;
		}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	cyl.material = mat
	_mat = mat

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = cyl
	multimesh.instance_count = pairs.size()

	for i in pairs.size():
		var a: Vector3 = pairs[i][0]
		var b: Vector3 = pairs[i][1]
		var dir := b - a
		var length := dir.length()
		var dir_norm := dir.normalized()
		var mid := (a + b) * 0.5
		var rot := Quaternion(Vector3.UP, dir_norm)
		var basis := Basis(rot) * Basis.from_scale(Vector3(line_radius, length, line_radius))
		multimesh.set_instance_transform(i, Transform3D(basis, mid))
		multimesh.set_instance_color(i, line_color)

func _on_fov_changed(fov: float) -> void:
	if _mat:
		_mat.set_shader_parameter("fov_scale", tan(deg_to_rad(fov) * 0.5) / _ref_tan)
