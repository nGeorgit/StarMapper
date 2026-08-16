extends Node3D
## Demo feature: overlays a skyculture's constellation artwork on the sphere, gnomonic-
## projected from its 3 HIP-anchored stars (res://data/constellation_sets/<id>.json
## "image" blocks, built by tools/parse_stellarium_data.py), and only shows the one
## artwork whose constellation is currently nearest the screen center. Explore-mode
## only, same as ConstellationNameLabels -- showing the answer would spoil a quiz.
##
## Data is sparse: most cultures ship no artwork at all, so most sets simply show
## nothing here. greek_dante is the only culture fully illustrated right now; this is
## step one toward drawing every culture's art properly.

@export var art_alpha := 0.3
@export var art_radius_mult := 1.01  ## slightly beyond SKY_RADIUS so ConstellationLines'
## depth-writing cylinders occlude the artwork where a line crosses it, instead of the
## art painting over the line.
@export var grid_subdivisions := 8  ## per axis; higher = smoother curvature for wide artwork
@export var center_threshold_fov_frac := 0.35  ## artwork shows once its constellation's
## center comes within (camera fov * this) degrees of the screen center
@export var is_background := false  ## true for decorative menu-background instances: always
## shows art, ignoring GameState.mode (which reflects the real gameplay scene, not this
## decorative one)

@onready var constellation_lines: MultiMeshInstance3D = $"../ConstellationLines"
@onready var camera_rig: CameraRig = $"../../CameraRig"

var _meshes: Dictionary = {}  ## constellation id -> MeshInstance3D
var _centers: Dictionary = {}  ## constellation id -> Vector2 (ra, dec)
var _shown_id := ""

func _ready() -> void:
	if not is_background and GameState.mode != GameState.Mode.EXPLORE:
		return
	ConstellationSets.set_changed.connect(_rebuild)
	await get_tree().process_frame  # let ConstellationLines finish loading its JSON first
	_rebuild()

func _process(_delta: float) -> void:
	if _meshes.is_empty() or not camera_rig:
		return
	_update_visible_art()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_meshes.clear()
	_centers.clear()
	_shown_id = ""

	for c in constellation_lines.constellations:
		if not c.has("image"):
			continue
		var mesh_inst := _build_mesh_instance(c["image"])
		if mesh_inst == null:
			continue
		mesh_inst.visible = false
		add_child(mesh_inst)
		_meshes[c["id"]] = mesh_inst
		_centers[c["id"]] = c["center"]

func _update_visible_art() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_center := viewport_size * 0.5
	var look_ra_dec := camera_rig.screen_point_to_ra_dec(screen_center)

	var threshold_deg: float = camera_rig.camera.fov * center_threshold_fov_frac
	var best_id := ""
	var best_dist := INF
	for id in _centers:
		var center: Vector2 = _centers[id]
		var dist := AstroMath.angular_separation_deg(look_ra_dec.x, look_ra_dec.y, center.x, center.y)
		if dist < best_dist:
			best_dist = dist
			best_id = id

	var winner := best_id if best_dist <= threshold_deg else ""
	if winner == _shown_id:
		return
	if _shown_id != "":
		_meshes[_shown_id].visible = false
	if winner != "":
		_meshes[winner].visible = true
	_shown_id = winner

## Builds one constellation's artwork as a curved grid mesh on the sphere: each grid
## vertex's pixel position is mapped to sky-space via barycentric coordinates in the
## 3-anchor pixel triangle (an exact affine fit -- 3 correspondences, 6 DOF, no least
## squares needed), producing tangent-plane coordinates that are then gnomonic-unprojected
## back onto the unit sphere. A flat quad would only line up at the 3 anchors themselves;
## subdividing keeps mid-image pixels aligned with the stars they're drawn around too.
func _build_mesh_instance(image: Dictionary) -> MeshInstance3D:
	if not ResourceLoader.exists(image["file"]):
		return null
	var texture: Texture2D = load(image["file"])
	if texture == null:
		return null

	var anchors: Array = image["anchors"]
	var w: float = image["size"][0]
	var h: float = image["size"][1]

	var sky_pts: Array[Vector3] = []
	var pix_pts: Array[Vector2] = []
	for a in anchors:
		sky_pts.append(AstroMath.ra_dec_to_vector3(a["ra"], a["dec"], 1.0))
		pix_pts.append(Vector2(a["pos"][0], a["pos"][1]))

	var center := (sky_pts[0] + sky_pts[1] + sky_pts[2]).normalized()
	var up_hint := Vector3.UP if absf(center.dot(Vector3.UP)) < 0.999 else Vector3.RIGHT
	var u := (up_hint - center * center.dot(up_hint)).normalized()
	var v := center.cross(u).normalized()

	## Gnomonic-project the 3 anchors into the tangent plane at `center`; barycentric
	## interpolation of these plane coordinates over the pixel triangle is exactly the
	## unique affine map taking each anchor's pixel to its tangent-plane position.
	var anchor_st: Array[Vector2] = []
	for p in sky_pts:
		var scale := 1.0 / p.dot(center)
		anchor_st.append(Vector2(p.dot(u) * scale, p.dot(v) * scale))

	var radius: float = AstroMath.SKY_RADIUS * art_radius_mult
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n := grid_subdivisions
	for row in range(n + 1):
		for col in range(n + 1):
			var px := (float(col) / n) * w
			var py := (float(row) / n) * h
			var bary := _barycentric(Vector2(px, py), pix_pts[0], pix_pts[1], pix_pts[2])
			var st_pt := anchor_st[0] * bary.x + anchor_st[1] * bary.y + anchor_st[2] * bary.z
			var dir := (center + u * st_pt.x + v * st_pt.y).normalized()
			st.set_uv(Vector2(px / w, py / h))
			st.add_vertex(dir * radius)

	var stride := n + 1
	for row in range(n):
		for col in range(n):
			var i0 := row * stride + col
			var i1 := i0 + 1
			var i2 := i0 + stride
			var i3 := i2 + 1
			st.add_index(i0)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i3)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = texture
	mat.albedo_color = Color(1.0, 1.0, 1.0, art_alpha)
	st.set_material(mat)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = st.commit()
	return mesh_inst

## Barycentric coordinates of p in triangle (a, b, c) -- weights (u, v, w) with
## u+v+w == 1 such that p == a*u + b*v + c*w. Valid (and useful) outside the triangle
## too, since it's just the affine map defined by the 3 points, extrapolated.
static func _barycentric(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denom := d00 * d11 - d01 * d01
	if absf(denom) < 1e-9:
		return Vector3(1.0, 0.0, 0.0)  # degenerate (collinear anchors) -- fall back to anchor a
	var v := (d11 * d20 - d01 * d21) / denom
	var w := (d00 * d21 - d01 * d20) / denom
	return Vector3(1.0 - v - w, v, w)
