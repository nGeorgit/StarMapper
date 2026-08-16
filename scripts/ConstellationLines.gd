extends MultiMeshInstance3D
## Draws constellation stick-figure lines on the celestial sphere as real cylinder
## geometry (not raw GL line primitives) so they get proper width and antialiasing
## instead of jagged 1px driver-dependent lines.
## Reads ConstellationSets.constellations (the active set, chosen/persisted by that
## autoload): [{ "id": "ORI", "name": "Orion", "segments": [[ra1,dec1,ra2,dec2], ...] }, ...]

@export var line_color := Color(0.4, 0.6, 1.0, 0.55)
@export var line_radius := 0.75
@export var radial_segments := 6
@export var highlight_color := Color(1.0, 0.85, 0.2, 1.0)  ## quiz "reveal" highlight, bright gold
@export var highlight_radius_mult := 2.5  ## thicker lines for the highlighted constellation
@export var star_gap := 6.0  ## world units trimmed off each segment end so the line doesn't cover the star marker
@export var reference_fov := 60.0  ## fov at which line_radius renders at its literal value; scaled up/down from there so screen-space width stays constant across zoom
@export var is_background := false  ## true for decorative menu-background instances: always
## shows lines at full explore-mode richness, ignoring GameState.mode (which reflects the
## real gameplay scene, not this decorative one)

@onready var camera_rig: CameraRig = $"../../CameraRig"

var constellations: Array = []  ## kept around so GameManager can look up boundaries/names; each
## dict gets a "center" (Vector2 ra/dec, degrees) key added at load time.

var _pairs: Array = []  ## flat [a: Vector3, b: Vector3] per line segment, world unit vectors
var _segment_ranges: Dictionary = {}  ## constellation id -> {"start": int, "count": int} into _pairs
var _highlighted_id := ""
var _lines_visible := true  ## quiz difficulty: Easy shows lines, Medium/Hard hide them
var _mat: ShaderMaterial  ## kept around so fov changes can update its scale uniform without rebuilding the mesh
var _ref_tan := 1.0  ## tan(reference_fov / 2), precomputed so _on_fov_changed is cheap

func _ready() -> void:
	if not is_background and GameState.mode == GameState.Mode.QUIZ and GameState.difficulty != GameState.Difficulty.EASY:
		_lines_visible = false
	_ref_tan = tan(deg_to_rad(reference_fov) * 0.5)
	ConstellationSets.set_changed.connect(_load_and_build)
	_load_and_build()
	if camera_rig:
		camera_rig.fov_changed.connect(_on_fov_changed)
		_on_fov_changed(camera_rig.camera.fov)

func _load_and_build() -> void:
	clear_highlight()
	## Duplicate so the "center" key added below doesn't mutate ConstellationSets'
	## cached data (harmless, but keeps the singleton's array pristine on set switches).
	constellations = ConstellationSets.constellations.duplicate(true)

	_pairs.clear()
	_segment_ranges.clear()
	for c in constellations:
		var start := _pairs.size()
		for seg in c["segments"]:
			var a := AstroMath.ra_dec_to_vector3(seg[0], seg[1])
			var b := AstroMath.ra_dec_to_vector3(seg[2], seg[3])
			_pairs.append([a, b])
		_segment_ranges[c["id"]] = {"start": start, "count": _pairs.size() - start}
		c["center"] = AstroMath.constellation_center(c["segments"])

	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = radial_segments
	cyl.rings = 0
	cyl.cap_top = false
	cyl.cap_bottom = false

	## Custom shader instead of StandardMaterial3D so radius can be rescaled on the GPU
	## by fov_scale (set from CameraRig.fov_changed) — keeps on-screen line width constant
	## across zoom without rewriting every instance transform on the CPU each frame.
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
	multimesh.instance_count = _pairs.size()

	for i in _pairs.size():
		_apply_segment_transform(i, line_radius)
		multimesh.set_instance_color(i, _base_color())

	if camera_rig:
		_on_fov_changed(camera_rig.camera.fov)  ## re-set the uniform on this freshly built material

	print("ConstellationLines: loaded %d constellations, %d line segments" % [constellations.size(), _pairs.size()])

## Rescales line radius on the GPU so its screen-space width stays constant regardless
## of zoom: world-space radius must grow with tan(fov/2) to cancel out the perspective
## shrink from a narrower fov (the player never moves, so distance to the sky sphere is
## fixed — fov alone drives apparent size here).
func _on_fov_changed(fov: float) -> void:
	if _mat:
		_mat.set_shader_parameter("fov_scale", tan(deg_to_rad(fov) * 0.5) / _ref_tan)

func _apply_segment_transform(i: int, radius: float) -> void:
	var a: Vector3 = _pairs[i][0]
	var b: Vector3 = _pairs[i][1]
	var dir := b - a
	var full_length := dir.length()
	var dir_norm := dir.normalized()
	## Trim both ends by star_gap (clamped so short segments don't invert) to leave
	## the star markers uncovered instead of buried under the line's endpoint.
	var gap: float = min(star_gap, full_length * 0.5 - 0.001)
	var trimmed_a := a + dir_norm * gap
	var trimmed_b := b - dir_norm * gap
	var mid := (trimmed_a + trimmed_b) * 0.5
	var length := full_length - gap * 2.0
	var rot := Quaternion(Vector3.UP, dir_norm)
	var basis := Basis(rot) * Basis.from_scale(Vector3(radius, length, radius))
	multimesh.set_instance_transform(i, Transform3D(basis, mid))

## Makes one constellation's lines thicker and brighter, so a quiz "reveal" stands out from
## the rest of the sky. Clears any previous highlight first (only one at a time).
func highlight_constellation(id: String) -> void:
	clear_highlight()
	if not _segment_ranges.has(id):
		return
	var seg_range: Dictionary = _segment_ranges[id]
	for i in range(seg_range["start"], seg_range["start"] + seg_range["count"]):
		_apply_segment_transform(i, line_radius * highlight_radius_mult)
		multimesh.set_instance_color(i, highlight_color)
	_highlighted_id = id

func clear_highlight() -> void:
	if _highlighted_id == "":
		return
	var seg_range: Dictionary = _segment_ranges[_highlighted_id]
	for i in range(seg_range["start"], seg_range["start"] + seg_range["count"]):
		_apply_segment_transform(i, line_radius)
		multimesh.set_instance_color(i, _base_color())
	_highlighted_id = ""

## line_color normally, or fully transparent when difficulty hides the base lines —
## the quiz's post-answer highlight_constellation() reveal ignores this and always shows.
func _base_color() -> Color:
	return line_color if _lines_visible else Color(line_color.r, line_color.g, line_color.b, 0.0)
