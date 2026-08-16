extends MultiMeshInstance3D
## Draws constellation stick-figure lines on the celestial sphere as real cylinder
## geometry (not raw GL line primitives) so they get proper width and antialiasing
## instead of jagged 1px driver-dependent lines.
## Expects res://data/constellations.json:
## [{ "id": "ORI", "name": "Orion", "segments": [[ra1,dec1,ra2,dec2], ...] }, ...]

@export var data_path := "res://data/constellations.json"
@export var line_color := Color(0.4, 0.6, 1.0, 0.55)
@export var line_radius := 1.1
@export var radial_segments := 6
@export var highlight_color := Color(1.0, 0.85, 0.2, 1.0)  ## quiz "reveal" highlight, bright gold
@export var highlight_radius_mult := 2.5  ## thicker lines for the highlighted constellation

var constellations: Array = []  ## kept around so GameManager can look up boundaries/names; each
## dict gets a "center" (Vector2 ra/dec, degrees) key added at load time.

var _pairs: Array = []  ## flat [a: Vector3, b: Vector3] per line segment, world unit vectors
var _segment_ranges: Dictionary = {}  ## constellation id -> {"start": int, "count": int} into _pairs
var _highlighted_id := ""
var _lines_visible := true  ## quiz difficulty: Easy shows lines, Medium/Hard hide them

func _ready() -> void:
	if GameState.mode == GameState.Mode.QUIZ and GameState.difficulty != GameState.Difficulty.EASY:
		_lines_visible = false
	_load_and_build()

func _load_and_build() -> void:
	if not FileAccess.file_exists(data_path):
		push_warning("ConstellationLines: %s not found, run tools/parse_stellarium_data.py first" % data_path)
		return

	var text := FileAccess.get_file_as_string(data_path)
	constellations = JSON.parse_string(text)
	if constellations == null:
		push_error("ConstellationLines: failed to parse %s" % data_path)
		return

	_pairs.clear()
	_segment_ranges.clear()
	for c in constellations:
		var start := _pairs.size()
		var center_sum := Vector3.ZERO
		for seg in c["segments"]:
			var a := AstroMath.ra_dec_to_vector3(seg[0], seg[1])
			var b := AstroMath.ra_dec_to_vector3(seg[2], seg[3])
			_pairs.append([a, b])
			center_sum += a.normalized()
			center_sum += b.normalized()
		_segment_ranges[c["id"]] = {"start": start, "count": _pairs.size() - start}
		c["center"] = AstroMath.vector3_to_ra_dec(center_sum.normalized())

	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = radial_segments
	cyl.rings = 0
	cyl.cap_top = false
	cyl.cap_bottom = false

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.vertex_color_use_as_albedo = true  ## per-instance color drives the actual line color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cyl.material = mat

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = cyl
	multimesh.instance_count = _pairs.size()

	for i in _pairs.size():
		_apply_segment_transform(i, line_radius)
		multimesh.set_instance_color(i, _base_color())

	print("ConstellationLines: loaded %d constellations, %d line segments" % [constellations.size(), _pairs.size()])

func _apply_segment_transform(i: int, radius: float) -> void:
	var a: Vector3 = _pairs[i][0]
	var b: Vector3 = _pairs[i][1]
	var mid := (a + b) * 0.5
	var dir := b - a
	var length := dir.length()
	var rot := Quaternion(Vector3.UP, dir.normalized())
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
