class_name StarField
extends MultiMeshInstance3D
## Renders the star catalog as soft round glowing points, colored by true spectral color,
## Stellarium-style: size and brightness follow the real magnitude flux curve, dimmer
## stars desaturate toward white (matches how the human eye loses color perception in
## low light), and how faint a star can be before it disappears depends on current zoom
## (wide view hides clutter, zooming in reveals fainter stars) — except stars that anchor
## a constellation's line figure, which stay visible at any zoom so shapes don't break apart
## -- membership comes from ConstellationSets.hip_ids for the currently active set, not
## anything baked into the catalog, so it follows the player's set choice live.
## Expects res://data/stars.json: [{ "id", "ra", "dec", "mag", "ci", "name"? }, ...]

@export var data_path := "res://data/stars.json"
@export var faintest_mag := 8.0  ## naked-eye limit; absolute cap regardless of zoom
@export var zoomed_out_mag_cutoff := 4.78  ## brightest-only cutoff at max_fov (fully zoomed out)
@export var brightest_anchor_mag := -1.46  ## Sirius; maps to max size/brightness
@export var base_point_size := 4.58
@export var min_visible_scale := 0.14  ## faintest stars: tiny pinpoints, not visible disks
@export var max_scale := 14.0  ## only the very brightest (Sirius-tier) should reach this
@export var size_gamma := 0.88  ## >1 = only near-Sirius stars get big; mid-bright (Vega-tier) stay modest
@export var min_visible_alpha := 0.53
@export var alpha_gamma := 2.0  ## <1 = alpha saturates toward 1 fast, so most visible stars read as
## crisp white/bright instead of a dim gray blend against the black background — under additive
## blending, brightness comes from color*alpha, and a low alpha mutes even a boosted color to gray.
## Contrast between stars now comes mainly from SIZE (size_gamma/max_scale), not from dimming alpha.
@export var desaturate_dim_stars := 0.0  ## 0=full color at all brightness, 1=faintest stars fully white
@export var brightness_boost := 2.0  ## pushes bright-star color past 1.0 so their additive core overexposes wider/whiter, like a real photo
@export var only_constellation_stars := false  ## quiz Easy/Medium: hide every star not part of a constellation

@onready var camera_rig: CameraRig = $"../../CameraRig"

var loaded_stars: Array = []  ## kept around so StarLabels can reuse without reparsing JSON
var _base_colors: PackedColorArray = []  ## RGB=true color, A=intrinsic brightness alpha (pre-cutoff)
var _mags: PackedFloat32Array = []
var _is_constellation_star: PackedByteArray = []
var _current_mag_cutoff := 99.0
var _quad: QuadMesh  ## kept around so the debug settings panel can live-resize the halo

func _ready() -> void:
	if GameState.mode == GameState.Mode.QUIZ and GameState.difficulty != GameState.Difficulty.HARD:
		only_constellation_stars = true
	ConstellationSets.set_changed.connect(reload)
	_load_stars()
	if camera_rig:
		camera_rig.fov_changed.connect(_on_fov_changed)
		_on_fov_changed(camera_rig.camera.fov)

## Live-tunes the point sprite's world size (the debug settings panel's "halo size"
## slider). Mutating the shared QuadMesh resource in place updates every instance
## immediately, no rebuild needed.
func set_base_point_size(v: float) -> void:
	base_point_size = v
	if _quad:
		_quad.size = Vector2(v, v)

## Re-runs the per-star size/alpha/color math against the already-loaded catalogue
## (no JSON re-parse, no mesh/shader rebuild) — cheap enough to call on every slider
## drag frame from the debug settings panel.
func refresh_visuals() -> void:
	if not multimesh:
		return
	for i in loaded_stars.size():
		var s: Dictionary = loaded_stars[i]
		var mag: float = s["mag"]
		var unit := _mag_to_unit(mag)

		var scale_factor: float = lerp(min_visible_scale, max_scale, pow(unit, size_gamma))
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * scale_factor), AstroMath.ra_dec_to_vector3(s["ra"], s["dec"])))

		var alpha: float = lerp(min_visible_alpha, 1.0, pow(unit, alpha_gamma))
		var true_color: Color = StarColor.bv_to_rgb(s.get("ci", 0.65))
		var color: Color = true_color.lerp(Color.WHITE, (1.0 - unit) * desaturate_dim_stars)
		var boost := 1.0 + unit * brightness_boost  # >1 lets additive blend overexpose bright cores
		_base_colors[i] = Color(color.r * boost, color.g * boost, color.b * boost, alpha)

	if camera_rig:
		_current_mag_cutoff = -999.0  # force _on_fov_changed to reapply against the new _base_colors
		_on_fov_changed(camera_rig.camera.fov)
	else:
		for i in loaded_stars.size():
			multimesh.set_instance_color(i, _base_colors[i])

## Forces the zoom -> star-count cutoff curve to reapply right now, bypassing the
## "imperceptible fov jitter" guard — used when the debug panel changes
## zoomed_out_mag_cutoff/faintest_mag and needs the visible set to update immediately
## even though the camera itself hasn't moved.
func reapply_mag_cutoff() -> void:
	if camera_rig:
		_current_mag_cutoff = -999.0
		_on_fov_changed(camera_rig.camera.fov)

## Full reload (re-filters the catalogue by faintest_mag, rebuilds the mesh/multimesh)
## — used when the debug panel changes faintest_mag, since that changes which stars
## exist at all, not just how they look.
func reload() -> void:
	_load_stars()
	reapply_mag_cutoff()

func _load_stars() -> void:
	if not FileAccess.file_exists(data_path):
		push_warning("StarField: %s not found, run tools/parse_stellarium_data.py first" % data_path)
		return

	var text := FileAccess.get_file_as_string(data_path)
	var stars: Array = JSON.parse_string(text)
	if stars == null:
		push_error("StarField: failed to parse %s" % data_path)
		return

	loaded_stars = stars.filter(func(s): return s["mag"] <= faintest_mag and (not only_constellation_stars or ConstellationSets.hip_ids.has(s["id"])))

	var quad := QuadMesh.new()
	quad.size = Vector2(base_point_size, base_point_size)

	# StandardMaterial3D.vertex_color_use_as_albedo silently drops MultiMesh instance
	# colors under this engine/renderer combo (confirmed via isolated shader test), so
	# color/alpha are applied by hand in a minimal shader instead.
	var shader := Shader.new()
	shader.code = """
		shader_type spatial;
		render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
		uniform sampler2D glow_tex;
		void vertex() {
			// Manual billboard: replace the rotation part of MODELVIEW with the
			// camera's basis, keeping this instance's translation and scale, so the
			// quad always faces the camera (built-in `billboard` render_mode collapses
			// MultiMesh scale-only instance transforms into a degenerate basis here).
			mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
			vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
			mv = mv * mat4(vec4(scale.x, 0.0, 0.0, 0.0), vec4(0.0, scale.y, 0.0, 0.0), vec4(0.0, 0.0, scale.z, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
			MODELVIEW_MATRIX = mv;
		}
		void fragment() {
			vec4 tex = texture(glow_tex, UV);
			ALBEDO = COLOR.rgb * tex.rgb;
			ALPHA = COLOR.a * tex.a;
		}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("glow_tex", _make_glow_texture())
	quad.material = mat

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = loaded_stars.size()

	_base_colors.resize(loaded_stars.size())
	_mags.resize(loaded_stars.size())
	_is_constellation_star.resize(loaded_stars.size())
	for i in loaded_stars.size():
		var s: Dictionary = loaded_stars[i]
		_mags[i] = s["mag"]
		_is_constellation_star[i] = 1 if ConstellationSets.hip_ids.has(s["id"]) else 0

	_quad = quad
	refresh_visuals()

	print("StarField: loaded %d/%d stars" % [loaded_stars.size(), stars.size()])

## Converts apparent magnitude to a 0..1 brightness unit using the real astronomical
## flux ratio (Pogson's law: each 5 magnitudes = 100x flux), so relative star sizes and
## brightness actually reflect the catalogue's mag column instead of a flattened scale.
## sqrt(flux) is the standard "stellar disk size by magnitude" compression used by
## planetarium renderers — it keeps the ~1500:1 real flux range from blowing out the
## faint end once it's remapped into a mobile-visible min/max scale.
func _mag_to_unit(mag: float) -> float:
	var flux := pow(10.0, -0.4 * mag)
	var flux_faint := pow(10.0, -0.4 * faintest_mag)
	var flux_bright := pow(10.0, -0.4 * brightest_anchor_mag)
	var t := (sqrt(flux) - sqrt(flux_faint)) / (sqrt(flux_bright) - sqrt(flux_faint))
	return clamp(t, 0.0, 1.0)

func _on_fov_changed(fov: float) -> void:
	var t: float = clamp((fov - camera_rig.min_fov) / (camera_rig.max_fov - camera_rig.min_fov), 0.0, 1.0)
	var new_cutoff: float = lerp(faintest_mag, zoomed_out_mag_cutoff, t)
	if abs(new_cutoff - _current_mag_cutoff) < 0.05:
		return  # avoid rewriting thousands of instances for imperceptible zoom jitter
	_current_mag_cutoff = new_cutoff
	for i in loaded_stars.size():
		var visible := _mags[i] <= _current_mag_cutoff or _is_constellation_star[i] == 1
		var c := _base_colors[i]
		multimesh.set_instance_color(i, Color(c.r, c.g, c.b, c.a if visible else 0.0))

## Small radial gradient texture: bright core fading to transparent edge, so billboard
## quads read as round soft points instead of hard-edged squares.
func _make_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0.9),
		Color(1, 1, 1, 0.25),
		Color(1, 1, 1, 0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.55, 1.0])

	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
